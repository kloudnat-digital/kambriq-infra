# kambriq-infra — working brief

Terraform IaC for KAMBRIQ on AWS `eu-central-1`. Three environments: `shared`
(cross-env primitives) → `dev` (live) → `prd` (**never deployed**).

Application code is in `../kambriq-webapp/`, whose `CLAUDE.md` carries the
method and the defect catalogue. **Read that one too** — the rules there (proof
by execution, one mutation per expectation, gate on the commit) apply here
without restatement. The chantier register is a separate file,
`../kambriq-webapp/docs/ops/registre-chantiers.md`.

---

## The one rule that matters most

**Validate locally. Never apply.**

```bash
cd envs/<env>
terraform init -reconfigure
terraform validate
terraform plan            # read it, all of it
```

`terraform apply` is **not yours to run**. `terraform-apply.yml` is a manual
`workflow_dispatch` and the human choosing the environment is the authorisation.
An apply here changes shared state that a running platform depends on; there is
no `--status Active` to undo it.

The same holds for anything that mutates AWS outside Terraform. If it changes
state, it waits for an explicit yes.

---

## The standards describe the codebase, not the code written after today

There is no double standard between new code and existing code. The rules in the
webapp brief - proof by execution, one mutation per expectation, no mechanism
that reports success by saying nothing - and the rules in this file describe what
these repositories are supposed to be, everywhere. They do not start applying at
the next commit.

Deliberately bounded, so it does not become a refactor that blocks delivery:

1. **Any file you touch in a PR comes up to standard in that same PR.** Not the
   whole module, not the whole repo: the file you were already editing. In
   Terraform that means the `.tf` file you edited gets its variable descriptions,
   its tags, and its cost note - not the module next door.
2. **If bringing a touched file up to standard would balloon the PR, stop and say
   so** rather than shipping half of it silently. A partial cleanup nobody
   mentions is worse than none: it leaves a file that looks reviewed and is not.
3. **The gap that remains is inventoried, not assumed.** `A7` in the register is
   a read-only pass over both repositories, file by file, listing where they do
   not meet these standards. Its output is a list, not a set of fixes. The debt
   becomes visible and finite rather than discovered one incident at a time.

### CLAUDE.md is updated in the same PR as the work it describes

Exactly like the register, and for the same reason.

These briefs carry the method and the defect catalogue, and both grow with every
chantier. A brief that lags behind the code it briefs is the stale
cross-reference defect applied to the one document whose entire job is being
trusted - and it is worse here than anywhere else, because this is the file every
session loads before it knows enough to doubt it.

A chantier that teaches something new adds it here, in the PR that closes the
chantier. Not afterwards, not in a docs pass, not "once it settles down".

---

## Drift, and how to actually find it

Two lessons, both expensive:

**An audit that reports a negative over a field it never read is worse than no
audit.** A drift check reported "no differences" for attributes it had not
retrieved — the AWS API returns them only when asked, and absence in the response
was read as absence of drift. **A field you did not read cannot be a field that
matches.** Before believing a negative result, confirm the check actually
retrieved the thing it claims to compare.

**`terraform plan` is the only thing that compares every declared attribute.**
Hand-rolled comparisons — `aws ecs describe-services` against a `.tf` file, a
script diffing a few keys — check the attributes somebody remembered. The plan
checks all of them, including the ones nobody thought to list. Use it as the
source of truth, and use scripts only to answer questions the plan does not ask.

---

## ECS Exec replaced the bastion

`modules/iam-roles-ecs/main.tf` grants the SSM channel; `enable_execute_command`
is on both dev services via `var.enable_ecs_exec`. The interactive path into the
private subnets is:

```bash
aws ecs execute-command --region eu-central-1 \
  --cluster kambriq-dev-cluster --task <task-id> \
  --container api --interactive --command /bin/sh
```

**There is no bastion host and there should not be one** — it was removed as a
cost and attack-surface reduction. Some ADRs still reference
`bastion_allowed_ssh_cidrs`; those references are historical and the variable is
not wired to a running instance.

One-off work (migrations, seeds, probes) runs as an **ephemeral task**, not on a
long-lived box:

```bash
aws ecs run-task --cluster kambriq-dev-cluster --task-definition kambriq-dev-api:<rev> \
  --launch-type FARGATE --network-configuration '<awsvpc config>' \
  --overrides '{"containerOverrides":[{"name":"api","command":["sh","-c","..."]}]}'
```

Container overrides cap at 8192 bytes. Read the result from CloudWatch
`/ecs/kambriq-dev-api`, stream `api/api/<task-id>` — **and read the container's
`exitCode`, not just the log**. A task whose log looks complete can still have
exited 1.

---

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
├── ecs-cluster/          # cluster + task execution role (Container Insights OFF - see below)
├── ecs-service/          # task definition + service + (optional) init container for migrations
├── ecr-repository/       # ECR + lifecycle policy
├── rds-postgres/         # RDS PG15 + parameter group + subnet group
├── elasticache-redis/    # Redis 7 replication group
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
  - **Sixteen payment-channel parameters, not twelve** (v03 section 9). Splitting mobile money into `OMO` (Orange) and `MOMO` (MTN) adds `ORANGE_MONEY_NUMBER`, `ORANGE_MONEY_NAME`, `MTN_MONEY_NUMBER`, `MTN_MONEY_NAME` - two operators, two numbers, two account names. The three older `MOBILE_MONEY_*` are **kept and read by no channel**: `PaymentChannelsService.FIELDS` still requires them at startup, so deleting them stops the API booting. Removing them is a webapp change first (drop them from `FIELDS`, deploy), infra second.
  - **Fictitious values on dev must not be diallable or payable.** A Cameroonian mobile number is `+237 6XX XXX XXX`; a placeholder of that shape can be copied into a transfer form and money leaves. The dev placeholders are not numbers at all and say so in their own text - `DEV-NUMERO-ORANGE-FICTIF-NE-PAS-UTILISER`.
  - **A third pattern exists, deliberately: values the application reads itself, at runtime.** The twelve `/kambriq/{env}/api/payment-channels/*` parameters (`G10`) are `SecureString`, are **not** in the `secrets:` block and **not** in `environment_variables`. Only the *prefix* is injected; the API reads the values through the SSM SDK with a 60-second cache.
    - Why: `G3` chose that reader so a wrong bank account number is corrected with one `aws ssm put-parameter --overwrite` and takes effect on the running task within a minute. As `secrets:` a correction would need a task restart; as `environment_variables` it would need an apply. Either would undo the design decision the parameters exist to serve.
    - They therefore carry `lifecycle { ignore_changes = [value] }`. Terraform creates them with visibly fictitious defaults and never touches the values again. **Removing that line makes every apply overwrite a corrected account number with a placeholder.**
    - Proved, not assumed: a `put-parameter` at 23:56 changed the bank name in an instruction email sent at 23:57 by the same process that had sent the old one at 23:55 - no restart, no deploy.
- **IAM split**:
  - **Role definitions** + always-on policies (SSM read, RDS describe) live in `modules/iam-roles-ecs/main.tf`.
  - **Resource-specific policy attachments** (e.g. S3 media access on the API task role) live in the env composition layer (`envs/dev/iam-media.tf`) - they cross both module boundaries (the role and the bucket ARN) so they belong where both are visible.
- **Tags**: every resource gets `Project=kambriq, Environment={env}, Service=<name>, ManagedBy=terraform` at minimum.

## Known drift / pitfalls

- **S3 versioning quirk**: once a bucket has been `Enabled`, S3 will NOT accept `Disabled` again - only `Suspended`. The `s3-media` module maps `var.versioning_enabled = false` -> `Suspended` for that reason.
- **Adopting resources that already exist: use `import` blocks, not a first create.** `lifecycle { ignore_changes = [value] }` protects a value on *subsequent* applies and does nothing on a first create, where `overwrite = true` writes the declared value over the live one. The twelve payment-channel parameters were created by hand and were not in state; without import blocks the plan called them creates, and any correction made between the plan and the apply would have been silently reverted. With `import` blocks in the root module (`envs/dev/imports-payment-channels.tf`) the same plan reads **12 to import, 13 to change** and the changes are tags and description only - `value` and `type` carry no `~` at all. Delete the blocks after the apply; once the resources are in state they are inert and only puzzle the next reader.
- **A `terraform plan` is a diff against state, not against reality.** When terraform adopts resources that already exist outside state, the plan shows clean creations and can warn about nothing - it has no prior version to compare. `G10`'s first draft declared the twelve payment-channel parameters as `String`; the live ones (hand-created) are `SecureString`, and the plan said so nowhere. Applying would have converted twelve bank details to plaintext. **Before applying a change that adopts existing resources, compare the declaration against the live resource yourself** - type, tier, encryption, tags.
- **SSM secrets must exist before first ECS apply**: `JWT_SECRET` and `DATABASE_URL_*` are read via `data.aws_ssm_parameter` if `use_existing_jwt_secret = true`. Pre-create with `aws ssm put-parameter --type SecureString` or pass via tfvars.
- **prd has never been applied**. Bootstrap prerequisites in `docs/adr/ADR-005-production-automation-prerequisites.md`.
- **Both API and web run in dev**: `enable_web_service = true` in `envs/dev/terraform.tfvars` - the API and web ECS services are both deployed.
- **NAT Gateway is single-AZ** (cost optimisation). No HA on outbound traffic. At roughly $39/month it is the largest single line in the bill; chantier `X2` decided a cheaper option and deliberately did **not** apply it before the delivery, because a shared-state network change days before a delivery trades $35/month against a broken dev.
- **Container Insights is disabled** and must stay that way unless somebody decides otherwise in writing. It cost $14.55 in August and $0.00 in September. Verified at the source with `aws ecs describe-clusters --include SETTINGS`, not inferred from the bill.
- **RDS `BackupRetentionPeriod` is 0 on dev, deliberately** - what a backup protects is reproducible from `migrate deploy` plus a restorative seed. **This must be revisited the moment prd exists**; it belongs on the ADR-005 checklist.
- **The RDS postgresql log group is capped at 7 days**, set outside Terraform because RDS creates that group itself. It is undeclared state and belongs in the RDS module next time that module is touched.
- **SES has production access** (granted 2026-09). The account is out of the sandbox, so mail reaches unverified addresses. Note that the mailbox simulator does not move `SentLast24Hours`, and that metric is not a real-time witness of anything: the `AWS/SES` `Send` and `Delivery` CloudWatch metrics are.
- **prd tag versioning**: `deploy-prd.yml` validates that the git tag `v*` matches `package.json` version exactly. Mismatch fails the deploy.

## Common commands

```bash
cd envs/<env>

terraform init -reconfigure
terraform validate
terraform plan
# terraform apply is NOT run from here. terraform-apply.yml, manual, human-chosen.

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

- ❌ Apply. At all. `terraform-apply.yml` is manual and the human running it is the authorisation.
- ❌ Modify `.tfstate` manually.
- ❌ Commit credentials, AMIs, instance IDs, or anything from `terraform output`.
- ❌ Add resources to `envs/<env>/main.tf` that should be a reusable module - extract to `modules/<name>/` first.
- ❌ Skip `envs/shared` updates that `dev`/`prd` depend on.
- ❌ Use `terraform.tfstate.backup` to roll back state - use `terraform state` operations instead.

## Chantier register

The cross-repo chantier register lives in
`kambriq-webapp/docs/ops/registre-chantiers.md`. It was moved out of that repo's
`CLAUDE.md` on 2026-09-04: Claude Code loads `CLAUDE.md` at the start of every
session, and the register had grown to 104 896 bytes that every session paid for
whether it touched them or not.

The rules that govern it are unchanged and live in that repo's brief: the PR
closing a chantier updates the register **in the same commit**; `EN COURS` names
the pending proof explicitly; `PROUVE` quotes it. So does the FinOps rule that
every chantier and every added resource states its cost impact — `None` is valid
and must be written.

Infra chantiers are listed there too. **This file is not a second register**, and
a second one would diverge from the first inside a week.

## Pointers

- Webapp repo: `../kambriq-webapp/`
- AWS account: `051551940370` / region `eu-central-1` / Route53 zone `Z00411721R2YKO3VFIPU4`
- Production bootstrap: `docs/adr/ADR-005-production-automation-prerequisites.md`
- Active PRs: `gh pr list --repo kloudnat-digital/kambriq-infra`
- Recent merged work: see commits since the latest tag (S3 media bucket config, IAM split, SSM extension all landed early May 2026)

---

### CI is billed per job, rounded up — five jobs of seconds cost five minutes

Measured 2026-09-09, against `Terraform Plan` run `34106681008`.

| job | measured | billed |
| --- | ---: | ---: |
| Detect changed environments | 5s | 1m |
| Shell Lint | 6s | 1m |
| Module Tests | 42s | 1m |
| Plan (shared) | 36s | 1m |
| Plan (dev) | 54s | 1m |
| **total** | **143s** | **5m** |

GitHub rounds each job up to the minute and charges per job, so 2m23s of work
bills as five minutes. The three cheapest jobs — 53 seconds between them — cost
three of those five.

**The rule: parallelism is bought, and the price is one rounded-up minute per
job.** Split when someone waits on the clock; merge when they only pay the bill.

What was applied here: concurrency on the plan (superseded PR runs cancelled),
and `timeout-minutes` on every job. The default is **360 minutes**, so one job
wedged on a provider call burns 18% of a monthly quota unnoticed.

**`terraform-apply` keeps `cancel-in-progress: false`, and that is not
symmetry.** A plan is a read: cancelling it loses nothing. A cancelled apply can
leave the state file locked and the real infrastructure half-changed — not a CI
problem but an AWS one.

Not applied: merging `detect-envs`, `shell-lint` and `module-tests` into one
job, which is the largest remaining saving at two billed minutes. `detect-envs`
publishes `outputs` that the `plan` matrix consumes, so the merge has to
preserve that contract and was not worth doing blind while no run could execute
to prove it.

## D15 - dev has no NAT gateway, and the tasks are in public subnets

Applied 12 September 2026. The gateway was the largest single line in the dev
bill, larger than the Fargate compute it served: **USD 40.55 a month**, against
USD 30.79 for the two services it existed to give egress to.

**The tasks are in the public subnets with `assign_public_ip = true`.** RDS and
ElastiCache stayed private and were not touched. That works because the load
balancer registers targets by private IP, and both database security groups
admit the task security group rather than a subnet CIDR - neither cares which
subnet the task sits in.

**VPC endpoints were priced and rejected.** The eight interface endpoints the two
IAM task roles require cost USD 140.16 a month at two availability zones, against
the gateway's USD 40.55, and even a minimal five-endpoint set is more than double.
Only the S3 gateway endpoint is free. At this scale the swap everyone reaches for
first costs three times what it saves.

### What the change removed, and what replaced it

A private subnet was the second layer in front of the tasks. Now the security
group is the only one. `scripts/assert-task-sg-closed.sh` asserts it on every
pull request, reading the **resolved plan** rather than the source, because the
ingress is a `dynamic` block and grepping cannot say what `for_each` produced.

### The route table, which is the part worth remembering

`route` is Optional **and** Computed on `aws_route_table`. Three consequences,
each of which cost an attempt:

- omitting the argument, or a `dynamic` block producing no blocks, reads as *not
  configured* rather than *no routes*. Terraform keeps the state value and
  reports the table unchanged, so the default route outlives the gateway;
- a standalone `aws_route` cannot remove it either: the route is in state as part
  of the table, so a resource at count zero that was never in state destroys
  nothing;
- an explicit list is the only form that can say "no routes", and its unused
  attributes must be `null`, not `""` - the provider stores them as empty strings
  and validates them as CIDRs on the way in.

A route whose target is deleted is not removed by AWS. It is kept and marked
`blackhole`, and traffic matching it is dropped silently.
`scripts/assert-no-blackhole-routes.sh` reads the **live** route tables for that
reason: a blackhole exists only after an apply, and no plan can show one.

### Apply order, which is not optional

`envs/dev` first, so the tasks hold their own egress, health confirmed behind the
load balancer, and only then `envs/shared`. Applying shared first strands the
running tasks with no route out: no image pulls, no logs, no parameter reads.

### A variable proved on the command line is a variable the apply never sees

`terraform-apply.yml` plans from the environment's tfvars and passes no `-var`.
The change was proved with `-var=enable_nat_gateway=false` and would have applied
nothing: the plan would have been empty and the run would have reported success
while the gateway survived. The flag lives in `envs/shared/terraform.tfvars`.

**Rollback is one line there, and it is planned rather than assumed:** with the
gateway re-enabled, the plan against the infrastructure as it stands is a strict
no-op.

## D22 - the account's management events are kept, by a trail of their own

`envs/shared/d22-management-events-trail.tf`. Planned 14 September 2026, **not
applied**. CloudTrail's event history keeps 90 days; until this trail nothing
kept CreateRole, AttachRolePolicy, PutBucketPolicy or CreateUser past them, on
an account several projects and several administrators share. Switching it on
recovers nothing: December 2025 stays unattributable.

### A single-region trail outside us-east-1 never sees IAM

The obvious fix was a flag on D14's trail. Read live, not from the source, that
trail is `IsMultiRegionTrail = false`, `IncludeGlobalServiceEvents = false`, with
advanced selectors for Data events only. Turning management events on there
would have recorded eu-central-1's management plane and missed exactly what the
chantier exists for: **IAM is global, and its events are delivered in
us-east-1.** The trail is therefore multi-region with global service events on,
and it is its own resource - D14's is a dev, KYC-scoped trail, and making it the
account's audit trail would have put the account's record under a dev name.

### The first copy is free; the second is billed

Management events cost nothing on the first trail that records them in a region
and USD 2.00 per 100 000 on any other. On 14 September no trail in the account,
in any region, recorded them (`describe-trails --include-shadow-trails`, every
region), so this one is the free copy. **Nothing else may switch management
events on** - D14's trail included - without reading that sentence first.

Read AND write, not write-only: `AssumeRole` and `AssumeRoleWithWebIdentity` are
logged `readOnly = true`, and they are how an action taken through a role is
traced to whoever took the role. Measured volume: about 1 140 management events
an hour, under USD 0.25 a month in S3. The bucket has no lifecycle rule, so it
accumulates; that is a decision for the register, not a default.

No key prefix, deliberately: the bucket policy grants `AWSLogs/<account>/*`, and
a prefix would put delivery outside the grant and log nothing.

### Plan with the Terraform the pipeline runs

Found while planning D19 and D22. `terraform-apply.yml` pins **1.12.0**; the
local binary was 1.9.4. Under 1.9.4 the dev plan was one change. Under 1.12.0 it
was two: the second, `aws_ssm_parameter.web_nextauth_secret` updated in place, is
invisible to 1.9.4 because it comes from write-only attribute handling
(`value_wo`) that only 1.11+ understands. A plan taken with another version is
not the plan that will be applied, in exactly the way a plan taken with `-var`
is not. Fetch the pinned version and verify it against HashiCorp's SHA256SUMS
before trusting a plan.

That NextAuth update is itself open. Its before and after are identical in every
attribute (compared by name; values are sensitive and were never printed), it
first appears in the dev plan of `fix/a30-rotate-db-password` on 13 September
11:08 UTC and in every dev plan since, and it was not in the last dev apply
(12 September). Whatever applies dev next applies it too.
