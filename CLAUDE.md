# kambriq-infra - Agent guide

Terraform IaC for the KAMBRIQ platform on AWS `eu-central-1`. Three environments: `shared` (cross-env primitives) -> `dev` (live) -> `prd` (never deployed).

The sister repo for application code (NestJS API, Next.js Web, Prisma) lives at `../kambriq-webapp/`.

## Branch & commit conventions

- Default branch is **`develop`** (NOT `build2Run` - that name is obsolete and any older docs referring to it are wrong).
- Always feature-branch off `develop`. PR targets `develop`. Squash merge.
- `terraform-plan.yml` runs on PR (no AWS creds, mock_provider for module unit tests under `modules/<name>/tests/`).
- `terraform-apply.yml` is **manual** (`workflow_dispatch` with environment choice: shared/dev/prd).
- `smoke-test.yml` runs automatically after `terraform-apply.yml` completes (curl retry + ECS service state checks).
- **Commitlint accepts uppercase subjects** in this repo (unlike `kambriq-webapp` which forces lowercase). `feat(infra): configure S3 media bucket policies, IAM, CORS for dev` is valid here.

## Apply order (mandatory)

```
1. envs/shared   (VPC, NAT, Route53, ACM, SES, GitHub OIDC, S3 state buckets, ECR repos)
2. envs/dev      OR envs/prd     (each references shared via `terraform_remote_state`)
```

Never apply `dev`/`prd` before `shared`. The shared stack outputs are the contract that env stacks consume.

## State backend (remote S3)

```
Bucket: kloudnat-infra-shared-store (eu-central-1)
Keys:
  kambriq/envs/shared/terraform.tfstate
  kambriq/envs/dev/terraform.tfstate
  kambriq/envs/prd/terraform.tfstate
```

Backend config lives in `envs/<env>/backend.tf`. Never modify `.tfstate` manually.

## Module structure

```
envs/{shared,dev,prd}/    # composition layer (env-specific wiring)
modules/
├── shared/               # VPC, subnets, NAT, ACM, SES, Route53
├── alb/                  # ALB HTTPS + listener rules + target groups
├── ecs-cluster/          # cluster + Container Insights + task execution role
├── ecs-service/          # task definition + service + (optional) init container for migrations
├── ecr-repository/       # ECR + lifecycle policy
├── rds-postgres/         # RDS PG15 + parameter group + subnet group
├── elasticache-redis/    # Redis 7 replication group
├── bastion/              # EC2 bastion + IAM SSM (port-forward to RDS)
├── iam-roles-ecs/        # task_api role + task_web role (definitions only)
├── s3-media/             # media bucket: CORS + lifecycle + versioning + SSE-S3
└── ssm-app-parameters/   # SSM Parameter Store - every API runtime config (secret + non-secret)
```

## Conventions

- **Region**: `eu-central-1`. Single source of truth. Hard-code any drift to `eu-west-3` as a bug.
- **AWS account**: `051551940370`. Domain: `kambriq.com` and `dev.kambriq.com`. Route53 zone: `Z00411721R2YKO3VFIPU4`.
- **Secrets handling**:
  - SSM Parameter Store SecureString under `/kambriq/{env}/{api,db,web}/...`. Never inline in `.tf` files (always via `var.<sensitive> = true`).
  - The ECS task pulls them via the `secrets:` block (`valueFrom = <ssm-arn>`), NOT `environment_variables:`.
  - Non-secret config also gets stored as plain SSM `String` for inventory consistency, AND injected directly into ECS `environment_variables` for runtime use.
- **IAM split**:
  - **Role definitions** + always-on policies (SSM read, RDS describe) live in `modules/iam-roles-ecs/main.tf`.
  - **Resource-specific policy attachments** (e.g. S3 media access on the API task role) live in the env composition layer (`envs/dev/iam-media.tf`) - they cross both module boundaries (the role and the bucket ARN) so they belong where both are visible.
- **Tags**: every resource gets `Project=kambriq, Environment={env}, Service=<name>, ManagedBy=terraform` at minimum.

## Known drift / pitfalls

- **Bastion replacement on every apply**: `module.bastion.aws_instance.bastion` uses `data "aws_ami" "al2023"` that resolves to the latest AL2023 AMI. AWS rotates AMIs frequently, so each apply may force replacement. The current choice is to live with the drift (replacement is fast). If you want pinning, add `lifecycle { ignore_changes = [ami] }`.
- **S3 versioning quirk**: once a bucket has been `Enabled`, S3 will NOT accept `Disabled` again - only `Suspended`. The `s3-media` module maps `var.versioning_enabled = false` -> `Suspended` for that reason.
- **SSM secrets must exist before first ECS apply**: `JWT_SECRET` and `DATABASE_URL_*` are read via `data.aws_ssm_parameter` if `use_existing_jwt_secret = true`. Pre-create with `aws ssm put-parameter --type SecureString` or pass via tfvars.
- **prd has never been applied**. Bootstrap prerequisites in `docs/adr/ADR-005-production-automation-prerequisites.md`.
- **Web service disabled in dev**: `enable_web_service = false` in `envs/dev/terraform.tfvars` - only the API ECS service runs in dev.
- **Bastion key pair**: `var.bastion_key_name` must reference an existing EC2 Key Pair in the region.
- **NAT Gateway is single-AZ** (cost optimization). No HA on outbound traffic in dev or prd.
- **SES sandbox**: if the AWS account is in SES sandbox, only verified email addresses receive mail. Sortir du sandbox before going prd.
- **prd tag versioning**: `deploy-prd.yml` validates that the git tag `v*` matches `package.json` version exactly. Mismatch fails the deploy.

## Common commands

```bash
cd envs/<env>

terraform init -reconfigure
terraform validate
terraform plan
terraform apply -auto-approve     # only on user instruction; CI is the canonical path

./scripts/set-github-vars.sh <env> owner/repo   # push outputs to GitHub vars/secrets
./scripts/smoke-test.sh                          # post-apply health checks
```

When developing modules, run unit tests (no AWS needed):
```bash
cd modules/<name>
terraform init
terraform test
```

## Don't

- ❌ Apply directly without a plan review.
- ❌ Modify `.tfstate` manually.
- ❌ Commit credentials, AMIs, instance IDs, or anything from `terraform output`.
- ❌ Add resources to `envs/<env>/main.tf` that should be a reusable module - extract to `modules/<name>/` first.
- ❌ Skip `envs/shared` updates that `dev`/`prd` depend on.
- ❌ Use `terraform.tfstate.backup` to roll back state - use `terraform state` operations instead.

## Pointers

- Webapp repo: `../kambriq-webapp/`
- AWS account: `051551940370` / region `eu-central-1` / Route53 zone `Z00411721R2YKO3VFIPU4`
- Production bootstrap: `docs/adr/ADR-005-production-automation-prerequisites.md`
- Active PRs: `gh pr list --repo kloudnat-digital/kambriq-infra`
- Recent merged work: see commits since the latest tag (S3 media bucket config, IAM split, SSM extension all landed early May 2026)
