# ADR-005: Production Automation Prerequisites — Full Develop → Live Pipeline

Date: 2026-04-17
Status: Accepted
Deciders: Kambriq Engineering Team

---

## Context and Problem Statement

The development environment (`dev.kambriq.com`) has a fully automated pipeline:
push to `develop` → quality gate → Docker build → migrations → ECS deploy → smoke test.

Production (`kambriq.com`) is **not yet live**. The `envs/prd/` Terraform stack has never been applied,
the GitHub `prd` environment does not exist, and `deploy-prd.yml` does not yet deploy the web service.

This ADR documents every step required — in exact order — to make the full pipeline
`develop → build → deploy to production` completely automated with no manual intervention
after the one-time bootstrap.

---

## Full Automated Flow (Target State)

```
Developer
  │
  ├─► push to develop
  │     └─► ci.yml
  │           quality: lint + typecheck + test (parallel)
  │           build-api → ECR: sha-{7char}, dev-latest
  │           build-web → ECR: sha-{7char}, web-dev-latest
  │           └─► deploy-dev.yml (auto-triggered)
  │                 migrations → deploy API + web → smoke test
  │                 → dev.kambriq.com ✅ (ALREADY WORKING)
  │
  └─► PR: develop → main
        merge
        └─► release-please.yml
              opens "Release PR" (bumps version, updates CHANGELOG)
              engineer reviews + merges
              └─► git tag v1.x.x created on main
                    └─► deploy-prd.yml
                          build API → ECR: v1.x.x, latest
                          build web → ECR: v1.x.x, web-prd-latest   ← TO BE ADDED
                          migrations (blocking, Fargate one-off task)
                          deploy API service → wait stable
                          deploy web service → wait stable            ← TO BE ADDED
                          smoke test
                          → kambriq.com ✅  (TARGET STATE)
```

---

## Phase 1 — One-Time AWS Infrastructure Bootstrap

These steps must be performed **once** by an engineer with Terraform + AWS CLI access.
After this phase, all future deployments are automated.

### 1.1 Shared stack (already applied, verify)

```bash
cd kambriq-infra/envs/shared
terraform init
terraform plan   # should show no changes if already applied
```

Verify these outputs exist:
- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`
- `github_oidc_provider_arn`

#### SES contact list — must be resolved before prd sends anything

**Amazon SES allows exactly one contact list per AWS account per region.**

`envs/dev/ses-newsletter.tf` creates `kambriq-newsletter` in `051551940370` /
`eu-central-1`, and the API is granted `ses:CreateContact` against it. If prd is
deployed into the **same account and region**, it cannot create a second list.
Both environments would write into `kambriq-newsletter`, so **test subscriptions
from dev would mix with real subscribers from prd** — in the same list, with no
way to tell them apart after the fact, and with real addresses exposed to
whatever dev does next.

This must be decided at prd bootstrap. The options, in rough order of
preference:

1. **Separate AWS account for prd.** Cleanest, and consistent with the
   separation the rest of this ADR assumes. Each account gets its own list.
2. **Separate region for prd's SES.** Contact lists are per region, so prd could
   use a different one. Costs a second verified identity and DKIM setup.
3. **Move the list to `envs/shared` and share it deliberately**, with the
   application prefixing or tagging contacts by environment. Cheapest, but it
   puts test data in the same list as real subscribers and relies on discipline.
4. **Do not deploy the newsletter to prd** until one of the above is chosen.

Doing nothing is not one of the options: the failure is silent, and it
contaminates a list containing real people's addresses.

---

### 1.2 Prepare production secrets (do this BEFORE terraform apply)

These sensitive values are NOT stored in git. Collect them before running Terraform:

| Secret | How to generate | Where it goes |
|--------|-----------------|---------------|
| `db_password` | **nothing to collect** | generated in-stack by `random_password`; see A30 and copy `envs/dev/a30-db-password.tf` |
| `jwt_secret` | `openssl rand -base64 64` | Set in `envs/prd/terraform.tfvars`: `jwt_secret = "..."` **or** pass via `-var` |
| `redis_auth_token` | `openssl rand -base64 32` | Set in `envs/prd/terraform.tfvars`: `redis_auth_token = "..."` |
| `AUTH_SECRET` (Next.js) | `openssl rand -base64 32` | Passed to SSM by Terraform as `NEXTAUTH_SECRET` |

> **Never commit real secrets, and prefer generating them to remembering not to.**
> `db_password` used to be a placeholder in `envs/dev/terraform.tfvars` with an
> instruction to override it at apply time. The instruction was never enforced -
> `terraform-apply.yml` passes no `-var` - so the placeholder was the live master
> password for seven months. A30 removed the variable entirely: with no variable,
> no placeholder is possible. `jwt_secret = ""` already falls through to
> `random_password`. Do the same for anything new rather than adding a rule
> somebody has to follow.

**Recommended approach — pass sensitive vars at apply time:**

```bash
terraform apply \
  -var jwt_secret="$(openssl rand -base64 64)" \
  -var redis_auth_token="$(openssl rand -base64 32)"
```

`db_password` is absent from that list on purpose: there is no such variable.

---

### 1.3 Fill remaining placeholders in `envs/prd/terraform.tfvars`

Open `kambriq-infra/envs/prd/terraform.tfvars` and set:

| Variable | Current value | Required value |
|----------|---------------|----------------|
| `api_acm_certificate_arn` | `"arn:aws:acm:eu-central-1:ACCOUNT:certificate/XXXXXXXX"` | Real ACM certificate ARN (from shared stack output or AWS Console) |
| `s3_media_bucket_name` | `""` | S3 bucket name if media upload is used, or leave empty |
| `alb_access_logs_bucket` | `""` | S3 bucket name for ALB logs (create bucket first, see §1.4) |
| `use_existing_jwt_secret` | `false` | Set `true` if re-running apply and secret already in SSM |

---

### 1.4 (Recommended) Create ALB access log S3 bucket

ALB access logs require an S3 bucket with the AWS ELB service account write permission.

```bash
BUCKET_NAME="kambriq-prd-alb-logs"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-central-1"

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Grant ELB service account write access (eu-central-1 ELB account: 054676820928)
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::054676820928:root" },
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/AWSLogs/'"$AWS_ACCOUNT_ID"'/*"
  }]
}'
```

Then set in `terraform.tfvars`:
```hcl
alb_access_logs_bucket = "kambriq-prd-alb-logs"
```

---

### 1.5 Apply prd stack

```bash
cd kambriq-infra/envs/prd
terraform init

# Dry run — review all resources to be created
terraform plan \
  -var jwt_secret="YOUR_JWT_SECRET" \
  -var redis_auth_token="YOUR_REDIS_TOKEN"

# Apply (takes ~10–15 min for RDS + ElastiCache to provision)
terraform apply \
  -var jwt_secret="YOUR_JWT_SECRET" \
  -var redis_auth_token="YOUR_REDIS_TOKEN"
```

**Resources created:**

| Resource | Name |
|----------|------|
| ECS Fargate cluster | `kambriq-prd-cluster` |
| ECS services | `kambriq-prd-api`, `kambriq-prd-web` |
| ECR repositories | `kambriq-api`, `kambriq-web` |
| RDS PostgreSQL (Multi-AZ) | `kambriq-postgres-prd` |
| ElastiCache Redis | `kambriq-prd-redis` |
| ALB + target groups | `kambriq-prd-alb` |
| SSM parameters | `/kambriq/prd/api/*`, `/kambriq/prd/web/*` |
| IAM OIDC role | `kambriq-prd-github-actions` |

**Key Terraform outputs to collect:**

```bash
terraform output github_actions_role_arn   # → AWS_ROLE_ARN secret in GitHub
terraform output ecr_api_url               # → ECR_REPO variable in GitHub
terraform output ecr_web_url               # → ECR_WEB_REPO variable in GitHub
terraform output ecs_cluster_name          # → ECS_CLUSTER variable in GitHub
terraform output ecs_api_service_name      # → ECS_SERVICE variable in GitHub
terraform output ecs_web_service_name      # → ECS_WEB_SERVICE variable in GitHub
terraform output ecs_api_task_family       # → ECS_TASK_DEFINITION variable in GitHub
terraform output ecs_web_task_family       # → ECS_WEB_TASK_DEFINITION variable in GitHub
terraform output private_subnet_ids        # → ECS_SUBNETS variable in GitHub
terraform output ecs_security_group_id     # → ECS_SECURITY_GROUPS variable in GitHub
```

---

### 1.6 Protect the RDS instance from accidental deletion

After first apply, enable `prevent_destroy` in the prd workspace:

1. Uncomment the `lifecycle` block in `modules/rds-postgres/main.tf`:
   ```hcl
   lifecycle {
     prevent_destroy = true
   }
   ```
2. Run `terraform apply` again (no infrastructure change — just records the guard in state).

---

## Phase 2 — GitHub Environment Configuration

### 2.1 Create GitHub Environment `prd`

In the `kambriq-webapp` repository:
**Settings → Environments → New environment** → name: `prd`

Add required protection rules:
- Required reviewers: 1 (prevents accidental production deploys)
- Deployment branches: `main` only

---

### 2.2 Set GitHub Environment variables and secrets

Set each value from the Terraform outputs collected in §1.5.

**Variables** (`vars.*`) in the `prd` environment:

| Variable | Value (from Terraform output) |
|----------|-------------------------------|
| `AWS_REGION` | `eu-central-1` |
| `ECR_REPO` | `terraform output ecr_api_url` |
| `ECR_WEB_REPO` | `terraform output ecr_web_url` |
| `ECS_CLUSTER` | `terraform output ecs_cluster_name` |
| `ECS_SERVICE` | `terraform output ecs_api_service_name` |
| `ECS_WEB_SERVICE` | `terraform output ecs_web_service_name` |
| `ECS_TASK_DEFINITION` | `terraform output ecs_api_task_family` |
| `ECS_WEB_TASK_DEFINITION` | `terraform output ecs_web_task_family` |
| `ECS_SUBNETS` | `terraform output private_subnet_ids` (comma-separated) |
| `ECS_SECURITY_GROUPS` | `terraform output ecs_security_group_id` |
| `CONTAINER_NAME` | `api` |
| `WEB_CONTAINER_NAME` | `web` |
| `ASSIGN_PUBLIC_IP` | `DISABLED` |
| `SMOKE_TEST_URL` | `https://kambriq.com/api/v1/health/ready` |
| `NEXT_PUBLIC_API_URL` | `https://kambriq.com` |
| `NEXT_PUBLIC_APP_URL` | `https://kambriq.com` |

**Secrets** (`secrets.*`) in the `prd` environment:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | `terraform output github_actions_role_arn` |
| `CODECOV_TOKEN` | Codecov token (optional) |

---

## Phase 3 — Application CI/CD Completion

### 3.1 Add web service to `deploy-prd.yml`

The `deploy-prd.yml` workflow currently only deploys the API. The web service steps must be added following the same pattern as `deploy-dev.yml`.

**Required additions to `deploy-prd.yml`:**

1. **Build and push web image** (after API image push):
   ```yaml
   - name: Build and push web image
     uses: docker/build-push-action@v3
     with:
       context: .
       file: docker/Dockerfile.web
       push: true
       platforms: linux/amd64
       tags: |
         ${{ vars.ECR_WEB_REPO }}:${{ github.ref_name }}
         ${{ vars.ECR_WEB_REPO }}:web-prd-latest
       build-args: |
         NEXT_PUBLIC_API_URL=${{ vars.NEXT_PUBLIC_API_URL }}
         NEXT_PUBLIC_APP_URL=${{ vars.NEXT_PUBLIC_APP_URL }}
       cache-from: type=gha,scope=web
       cache-to: type=gha,mode=max,scope=web
   ```

2. **Register web task definition and deploy web service** (after API service is stable):
   ```yaml
   - name: Register web task definition
     id: task-def-web
     uses: aws-actions/amazon-ecs-render-task-definition@v1
     with:
       task-definition-arn: ${{ vars.ECS_WEB_TASK_DEFINITION }}
       container-name: ${{ vars.WEB_CONTAINER_NAME }}
       image: ${{ vars.ECR_WEB_REPO }}:${{ github.ref_name }}

   - name: Deploy web service
     uses: aws-actions/amazon-ecs-deploy-task-definition@v1
     with:
       task-definition: ${{ steps.task-def-web.outputs.task-definition }}
       service: ${{ vars.ECS_WEB_SERVICE }}
       cluster: ${{ vars.ECS_CLUSTER }}
       wait-for-service-stability: true
   ```

**File to modify:** `kambriq-webapp/.github/workflows/deploy-prd.yml`

---

### 3.2 Verify `release-please.yml` is configured

Check that `release-please.yml` exists and is targeting `main`:

```yaml
on:
  push:
    branches: [main]
```

The workflow creates a Release PR on every push to `main`. When the Release PR is merged, `release-please` creates the `v*` tag that triggers `deploy-prd.yml`.

No changes needed if `release-please.yml` already exists and targets `main`.

---

## Phase 4 — First Production Deploy

After phases 1–3 are complete, trigger the first production deployment:

### 4.1 Push a release

```bash
# Ensure develop is stable and dev smoke test passes
git checkout main
git merge develop
git push origin main
# → release-please opens a Release PR automatically

# Review and merge the Release PR on GitHub
# → release-please creates tag v0.1.0 (or first semver bump)
# → deploy-prd.yml triggers automatically
```

### 4.2 Seed initial production data (one-time)

After the first deploy succeeds, if you need to seed roles, admin user, or base data:

```bash
# Trigger via GitHub Actions workflow_dispatch
# Actions → Deploy Prd → Run workflow
# Set run_seed=true
```

> Seed runs only when explicitly requested and never touches prod data automatically.

### 4.3 Verify production

```bash
curl -fsS https://kambriq.com/api/v1/health/ready
# → {"status":"ok"}

curl -fsS https://kambriq.com/health
# → {"status":"ok"}
```

---

## Summary Checklist

### Infrastructure (kambriq-infra)

- [ ] Collect sensitive secrets (jwt_secret, redis_auth_token - `db_password` is generated, A30)
- [ ] Update `envs/prd/terraform.tfvars` with real `api_acm_certificate_arn`
- [ ] Create ALB access log S3 bucket (optional but recommended)
- [ ] Run `terraform apply` for `envs/prd/`
- [ ] Collect all Terraform outputs for GitHub environment
- [ ] Uncomment `lifecycle { prevent_destroy = true }` in RDS module after first apply

### Application CI/CD (kambriq-webapp)

- [ ] Create GitHub Environment `prd` with required reviewer protection
- [ ] Populate all `prd` environment variables (from Terraform outputs)
- [ ] Add `AWS_ROLE_ARN` secret to `prd` environment
- [ ] Add web image build + deploy steps to `deploy-prd.yml`
- [ ] Verify `release-please.yml` targets `main`

### First Production Deploy

- [ ] Push a PR from `develop` → `main`, merge it
- [ ] Merge the Release PR created by release-please → triggers `v0.1.0` tag
- [ ] `deploy-prd.yml` runs automatically: build → migrate → deploy API + web → smoke test
- [ ] Optionally seed initial data via `workflow_dispatch` with `run_seed=true`
- [ ] Verify `https://kambriq.com` is live and healthy

---

## Consequences

- **One-time effort**: After the bootstrap phases above, all future production deployments are triggered by merging the release-please PR. No manual steps required.
- **Secret management**: `db_password` is generated in-stack and has no variable (A30). `jwt_secret` and `redis_auth_token` must never be committed - use `-var` flags or a gitignored local file, and prefer converting them to `random_password` too. All are stored as SSM SecureString after `terraform apply`.
- **Multi-AZ cost**: Enabling `rds_multi_az = true` for prd roughly doubles the RDS cost (one standby instance). This is required for production availability.
- **Web prd image tag**: The web image will be tagged with the semver version (`v1.x.x`) and `web-prd-latest`. Unlike dev, the tag is human-readable and tied to a release.
- **GitHub Environment protection**: The `prd` environment requires 1 reviewer approval before a deployment can run. This prevents accidental triggers from automated workflows.
