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
  - **Thirteen payment-channel parameters** (v03 section 9 said sixteen: twelve plus the four per-operator ones). Splitting mobile money into `OMO` (Orange) and `MOMO` (MTN) added `ORANGE_MONEY_NUMBER`, `ORANGE_MONEY_NAME`, `MTN_MONEY_NUMBER`, `MTN_MONEY_NAME` - two operators, two numbers, two account names. The three older `MOBILE_MONEY_*` were then read by no channel and still required at startup, so they could not simply be deleted. **D9 removed them in the only safe order:** out of `PaymentChannelsService.FIELDS` in the webapp, deployed, the API seen reaching steady state and answering `/health` without them - and only then out of `payment_channel_defaults` here, which destroys the three parameters on the next apply. Deleting them with `aws ssm delete-parameter` instead would have been undone: they are in terraform state, so the next apply recreates them with their placeholder values.
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

### CI costs nothing here, because both repositories are public

**Corrected 2026-09-16.** This section used to assert that CI is billed per job,
rounded up, and that claim was steering decisions. It is false for these
repositories. Both `kambriq-infra` and `kambriq-webapp` are
`visibility=public`, and GitHub does not meter Actions on public repositories:
every run of 2026-09-16, on GitHub-hosted `ubuntu-latest` runners, reports
`billable.UBUNTU.total_ms = 0` from `/actions/runs/{id}/timing` — including the
ten-job webapp CI run whose wall clock was 21m31s. Read from the API, not
assumed. **Net Actions cost for this work: USD 0.00.**

The per-job rounding rule below is real GitHub behaviour; it is simply not in
force here. **It starts applying the day a repository goes private**, so the
table is kept and its third column reads as a conditional, not as a bill.

Measured 2026-09-09, against `Terraform Plan` run `34106681008`.

| job | measured | would be billed if private |
| --- | ---: | ---: |
| Detect changed environments | 5s | 1m |
| Shell Lint | 6s | 1m |
| Module Tests | 42s | 1m |
| Plan (shared) | 36s | 1m |
| Plan (dev) | 54s | 1m |
| **total** | **143s** | **5m** |

On a private repository GitHub rounds each job up to the minute and charges per
job, so 2m23s of work would bill as five minutes, and the three cheapest jobs —
53 seconds between them — would cost three of those five. **Parallelism would be
bought, at one rounded-up minute per job.** On these public repositories it is
free, so split whenever someone waits on the clock and stop trading latency for
a bill that does not exist.

What was applied here: concurrency on the plan (superseded PR runs cancelled),
and `timeout-minutes` on every job. The default is **360 minutes**: on a public
repository that costs nothing, but it still holds a runner and a `concurrency`
slot for six hours; on a private one it would burn 18% of a monthly quota
unnoticed.

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
was two: the second, `aws_ssm_parameter.web_nextauth_secret` updated in place. A
plan taken with another version is not the plan that will be applied, in exactly
the way a plan taken with `-var` is not. Fetch the pinned version and verify it
against HashiCorp's SHA256SUMS before trusting a plan.

**Retracted, and kept as a retraction.** This section first said the extra line
came from write-only attribute handling (`value_wo`). It did not - the provider
was never the cause. What it actually was is the next section.

## D23 - a local apply writes the state in its own Terraform version

**The update was a sensitivity change, not a value change.**
`web_nextauth_secret` carries the tag
`AutoGenerated = var.nextauth_secret == "" ? "true" : "false"`. Terraform 1.10.0
changed conditional expressions so that _"marks must be combined from all values
within the expression"_ (its changelog, verbatim), so a conditional that reads a
sensitive variable now yields a sensitive result. Under 1.12.0 that tag is marked
sensitive; under 1.9.4 it is not. Terraform core turns a no-op into an Update
whenever the planned value's marks differ from the state's
(`internal/terraform/node_resource_abstract_instance.go`, the `valueMarksEqual`
check) - an in-place update whose before and after are identical. Compared by
attribute name and as booleans only: identical values, and `after_sensitive`
carrying `tags.AutoGenerated` where the state did not.

**The state lost the mark because Terraform 1.9.4 wrote it.** The dev state
bucket has no versioning, so only one version of the state object survives:
written **2026-09-13 21:10:11 UTC**, `terraform_version` **1.9.4**. CloudTrail for
21:06-21:12 shows the IAM user `vmiaff` issuing `ec2:CreateTags`,
`s3:PutBucketTagging`, `iam:TagRole` and `iam:TagOpenIDConnectProvider` - the
default-tags change applied from a laptop, outside `terraform-apply.yml`, before
its pull request merged. The line first appeared at 11:08 the same day, so an
earlier local write happened too; with no versioning that one cannot be shown.

**Not introduced by #36.** Its own plan was merely the first to show it: replayed
against today's state, #36's parent plans the same update.

**The rule.** A local `terraform apply`, `import`, `state rm` or `state mv` writes
the state with the Terraform version of the machine that ran it, and records that
version in the state. A state written by an older version is not the state the
pipeline plans against, and the difference arrives later as a change nobody made,
on a resource nobody touched - here, the secret that signs every session. Change
state only through `terraform-apply.yml`. If a local state operation is ever
unavoidable, run it with the pinned version and say so in the pull request.
**Nothing enforces this yet**: a `required_version` pinned to the pipeline's
version in each root module would make an older binary refuse to touch the
state, and is a separate change to decide.

## D21 - who can read the state, and the key barrier it did not have

`envs/shared/d21-state-kms.tf`. The state carries secrets in cleartext (A29,
A30), so the only question is who can read the object. **Answered by
measurement, not by reading policies:** `simulate-principal-policy` for
`s3:GetObject` on
`arn:aws:s3:::kloudnat-infra-shared-store/kambriq/envs/dev/terraform.tfstate`,
run over all 5 users and all 32 roles in the account on 16 September 2026.

### Five readers, not four

`vmiaff`, `uekeum`, `gitops.admin`, `kambriq-infra-github-actions` — and
`AWSReservedSSO_AdministratorAccess_c1b30cb73dd006be`, the IAM Identity Center
permission set (SAML, `AdministratorAccess`, 12-hour sessions, last used
2025-04-25). The D wave brief said four; the fifth is real and is **named in the
key policy on purpose**. Leaving it out would not lock it out - it holds `kms:*`
through IAM and can call `kms:PutKeyPolicy` - and would make the barrier read
stronger than it is. Whether that permission set should reach this account at
all is an Identity Center assignment decision, not a key policy one.

### The barrier is the key policy, and it starts holding per object

SSE-S3 has no key policy: `s3:GetObject` alone decrypts. Under a CMK a reader
needs **both** `s3:GetObject` and `kms:Decrypt` on that key. S3 encrypts at
write time, so each state object keeps SSE-S3 until it is rewritten: the shared
object on the next shared apply after the backend change, the dev object on the
next dev apply. Until then, that object is still readable with GetObject alone -
say which apply moved which object, rather than announcing the barrier when the
key is created.

### The key is selected by the backend, not by the bucket

`kloudnat-infra-shared-store` is not ours alone: it also holds three legacy
kambriq states and a top-level `shared/` prefix, in an account that also runs
fotomena's EKS clusters and argocd. A bucket **default** encryption key would
re-encrypt every future write by every writer, including principals this key
policy does not name, and break their applies. So `kms_key_id` goes in
`backend "s3"`, which scopes it to the two objects Terraform writes.

### Two pull requests, because the apply has no pause

`terraform-apply.yml` plans and applies in one job. The key must exist before
any backend names it, so the key ships alone and the backend change follows. In
the other order, a dev apply creates resources and then fails writing state to a
key that does not exist.

### Cost, and what it does not cover

USD 1.00 per month for the key, plus USD 0.03 per 10 000 requests, which rounds
to nothing at a few state writes a day. Not free - the figure is a dollar.

All five readers are administrators. This stops a principal that was never meant
to read the state; it does not stop somebody who is supposed to be an
administrator. It also does nothing about the state being cleartext inside the
object, and nothing about the bucket having **no versioning** - a bad state
write is unrecoverable, which is how D23's evidence went missing.

### A key policy must let somebody change the key policy

The first apply was **refused**, and the refusal was right:

```
MalformedPolicyDocumentException: The new key policy will not allow you to
update the key policy in the future.
```

`terraform-apply.yml` run 35134521387, 2026-09-16 18:30 UTC. The plan was
exactly the local one (`2 to add`), no key and no alias were created, and the
state was rewritten unchanged at the end of the run.

The cause is KMS's policy lockout safety check. A key policy is not like other
resource policies: *"an AWS KMS key policy does not automatically give
permission to the account or any of its principals. To give permission to any
principal, including the account principal, you must use a key policy statement
that provides the permission explicitly."* The first version named only the
three human administrators, so the role actually calling `CreateKey` - the
pipeline - could never have called `PutKeyPolicy` afterwards, and KMS refuses
that up front rather than letting a key become unmanageable.

**The fix is to name the manager, not to bypass the check.**
`bypass_policy_lockout_safety_check = true` exists and is not used here: it
silences the guard instead of satisfying it, and AWS's own example of how a key
becomes reachable only through Support is a policy naming principals that can
later be deleted.

**And the cost of that fix, stated rather than hidden:** the apply role can now
rewrite this key policy, so it can grant itself the data-plane permissions the
second statement withholds. It could do that before D16 (`Action:*` on
`Resource:*`) and can still do it after (`iam:*` over `kambriq-*`). What this key
buys is a barrier against a principal never meant to read the state - not
against the pipeline that manages it.

## D16 - the plan role and the apply role are not the same role

`envs/shared/d16-plan-and-apply-roles.tf`, plus the apply role's policy in
`envs/shared/main.tf` and one line in `terraform-plan.yml`.

### Branch protection guards merges, not AWS

`terraform-apply.yml` is a `workflow_dispatch`, launchable from any ref. Read
live, not deduced: all three environments (`dev`, `prd`, `shared`) have
`"protection_rules": []` and no deployment branch policy, and develop's
protection is one required check with `reviews=0` and `enforce_admins=false`.
So the shortest route to an unreviewed apply does not go through a pull request,
and once required checks are in place the feeling of protection is real for
merges and **false** for infrastructure.

### One role, one claim - for both plan and apply

Both workflows declare `environment: <env>` and read `secrets.AWS_ROLE_ARN`, an
environment secret present in all three environments. The role trusts exactly
`repo:kloudnat-digital/kambriq-infra:environment:{dev,shared}`, so a pull-request
plan and a dispatched apply present the **same** `sub` and receive the **same**
credentials - `Action: *` on `Resource: *`.

No claim available here can carry a branch restriction: the repository uses the
default subject format (`use_default: true`, read through the API), and a job
that declares an environment loses the ref from `sub`. IAM cannot read `ref`.

### The split is by environment name, because that is what `sub` carries

`dev-plan` and `shared-plan` are declared by the plan workflow; the plan role
trusts only those two subs. A second secret name in the same environments would
change which ARN the plan job reads while leaving both roles reachable from one
claim - the trust policy could not tell them apart. Creating those two
environments and their `AWS_ROLE_ARN` is a GitHub settings change, listed in the
pull request.

### What a plan needs - and the lock that does not exist

The read surface comes from the two states (134 addresses in dev, 33 in shared).
**The brief's premise that a plan needs write access to a lock table is false
here:** neither backend block sets `dynamodb_table` or `use_lockfile`, the
account has no DynamoDB table, and `terraform-plan.yml` already says "it
acquires no state lock". Nothing locks these states - not the plan, and **not
the apply either**, so two concurrent applies can both write. That is a separate
defect, recorded here rather than fixed in passing. If `use_lockfile` is ever
enabled, the plan role needs `s3:PutObject`/`s3:DeleteObject` on `<key>.tflock`.

### Read power is not reduced

A plan refreshes 57 `aws_ssm_parameter` resources, which reads their values. The
plan role can therefore read every `/kambriq/dev/*` SecureString, `JWT_SECRET`
and the four `DATABASE_URL`s included. The split removes the power to **change**
the estate; a leaked plan credential is still a leaked set of secrets.

### Three ways a policy lies about what it grants

All three were found on 2026-09-16, **after** the split was applied, by
measuring the live roles rather than reading the HCL. Each produced a confident
wrong answer first. They are properties of IAM, not of this estate.

**An action simulated without its resource is not the action the pipeline
performs.** `simulate-principal-policy` defaults `--resource-arns` to `*`, and a
resource-scoped statement can never match `*`. Seven mutating actions therefore
read as `implicitDeny` for the *apply* role, and
`scripts/d16-prove-role-split.sh` reported that the apply role had lost powers
it still held. Re-simulated against real ARNs, all seven are
`plan=implicitDeny, apply=allowed`. The split was never broken; the measurement
was. Every case in that script now carries a resource.

**Some actions take no resource at all, and a scoped statement grants them
nothing.** IAM evaluates them only against `*`, however plainly a scoped
statement lists them. `ssm:DescribeParameters` sat in the plan role's
`ReadTheProjectParameters` (scoped to `parameter/kambriq/*`) and was refused
every time — and the AWS provider calls it on **every** `aws_ssm_parameter`
refresh, so a dev plan or apply under either role would have failed on it. The
shared apply of 18:43Z survived only because shared owns no SSM parameters.
`s3:GetAccountPublicAccessBlock` was the same class in the other direction: the
plan role never had it, and D14a's `aws_s3_account_public_access_block` is
refreshed by every shared plan. Which actions are in this class is a fact of the
Service Authorization Reference — an empty resource-type column — not a
judgement.

**A service prefix IAM does not know is a silent deny, not an error.** Both
policies said `sesv2:`; the SESv2 API authorises against `ses:` ("Amazon Simple
Email Service v2 (service prefix: `ses`)"). `sesv2:*` matched nothing and
refused nothing, and `envs/shared/ses-newsletter.tf` manages an
`aws_sesv2_contact_list`. **The simulator cannot catch this**: it string-matches,
and returns `implicitDeny` for `notarealservice:DoThing` rather than rejecting
it — so it cheerfully agreed that `sesv2:*` allows `sesv2:GetContactList`, which
is true and means nothing. The instrument is
`aws accessanalyzer validate-policy`, which returns
`INVALID_SERVICE_IN_ACTION` at severity ERROR. It is now stage 0 of the proof
script, and it is the only stage that can see this class of defect.

All three were invisible before the split because the old policy was `Action: *`
on `Resource: *`. **Replacing a wildcard with an enumeration turns every
mis-spelled or mis-scoped entry from harmless into load-bearing**, and nothing
in `terraform validate`, `fmt`, or a plan checks that an action exists. Run
`validate-policy` over a policy before applying it, not after.

### A policy repair cannot be applied by a plan that the same policy breaks

The sharpest lesson of 2026-09-16. It cost two extra merges and an `--admin`
override, and it will happen again to anyone who enumerates this role's policy.

**A pull request that changes the CI role's own policy cannot be validated by its
own plan.** The pre-merge plan runs under the OLD credentials, so it fails on the
very defect the PR repairs. #59's `Plan (shared)` failed exactly that way and CI
Gate refused it. That is expected and it is not evidence against the change — but
it means the gate is silent on the only question that matters. **The proof has to
come from somewhere the broken credentials are not:**
`aws iam simulate-custom-policy` against the *proposed* document, and
`accessanalyzer validate-policy` on it. Both were run before merging, and both
passed: every refused action became `allowed`, and the plan role stayed refused
on all five writes.

**Worse — the apply could not run either.** `terraform-apply.yml` plans and
applies in one run, so the apply inherits whatever the plan can read. Run
`35143582139` died at step 9 (Terraform plan) on `ses:GetContactList`; step 11
(Terraform apply) was **skipped** and no state was written. The one apply that
would restore the permission needed that permission to get past its own refresh.
**A repair that is a prerequisite for itself.**

The way out was measured, not guessed — four local plans, pinned 1.12.0, same
tree:

| variant | managed refreshes | reads SES | plan |
| --- | ---: | --- | --- |
| plain (what CI runs) | 29 | **yes** | fails in CI |
| `-refresh=false` | 0 | no | 0 add / 2 change |
| `-refresh=false -target=…` | 0 | no | 0 add / 2 change |
| **`-target=…`** | **5** | no | 0 add / 2 change |

`-target` alone is the right instrument: it still refreshes the five resources
being changed — the OIDC provider, both roles, both role policies — so it is not
a blind apply, and it never reads SES. `terraform-apply.yml` therefore accepts an
optional `extra_plan_args` input (default empty, #60). **A targeted apply is a
partial apply**, so the step logs `PARTIAL APPLY` and the run summary states
which arguments were in effect. It exists to break a deadlock, not for routine
use.

What the repair reported, against a local plan taken immediately before it:
`Apply complete! Resources: 0 added, 2 changed, 0 destroyed`, matching
`Plan: 0 to add, 2 to change, 0 to destroy` exactly. The live documents are
canonically identical to the ones the plan intended (`sha256 53b95eec…`,
`fafe5e8b…`), and both environments then plan clean under the pipeline.

**The general rule: before replacing a wildcard in a CI role's own policy, work
out how you would apply the fix if you got it wrong.** If the answer is "through
the pipeline", check that the pipeline's own read surface does not include the
permission you are about to remove.

### Two older invalid actions, in other subjects' policies

The same account-wide sweep (`validate-policy` over every inline policy of every
`kambriq-*` role) found two pre-dating this work, left for their own subjects
rather than fixed in passing: `s3:HeadObject` in `kambriq-media-dev-access`
(there is no such IAM action; the HeadObject API authorises as `s3:GetObject`)
and `ecs:Wait` in `kambriq-dev-github-actions` (no such action; `aws ecs wait`
polls `DescribeServices` client-side).

**Both are inert, checked rather than assumed:** the media policy also grants
`s3:GetObject` and the deploy policy also grants `ecs:DescribeServices`, so each
API call lands on a permission that exists. They are dead entries that make a
policy read wider than it is — worth deleting, but nothing is failing because of
them. That is the difference between these two and the `sesv2:` defect above,
where nothing else granted what the call needed.

### What it does not cover

Both repository administrators (`Ekeu`, `visquis-miaffossa`) can still dispatch
`terraform-apply.yml` from any ref, with no reviewer. Anyone with write access
can push a workflow change and dispatch it. The apply role still holds `iam:*`
over `kambriq-*` principals, so it can rewrite its own policy - narrowing that
needs a permissions boundary. What this buys is that a plan cannot change
anything, and that the apply role can no longer touch fotomena's EKS clusters,
argocd, Organizations or Identity Center.
