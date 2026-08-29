# KAMBRIQ AWS Infrastructure as Code (Terraform)

## Overview
This repository provisions shared AWS infrastructure and environment-specific
workloads for the KAMBRIQ platform using Terraform.

## Environments
Environments live under `envs/`:
- `envs/shared` - VPC, subnets, NAT, Route53 lookups, and shared S3 buckets.
- `envs/dev` - ECS, RDS, Redis, ALB, Route53 records, and SSM parameters.

## Remote State
All environments store state in:
- S3 bucket: `kloudnat-infra-shared-store`
- Keys:
  - `kambriq/envs/shared/terraform.tfstate`
  - `kambriq/envs/dev/terraform.tfstate`

## Apply Order
1. `envs/shared`
2. `envs/dev`

## Database Credentials (SSM)
- The RDS master password is stored in SSM at
  `/kambriq/{env}/db/DB_PASSWORD` (SecureString).
- Do not store the real password in git. Use `TF_VAR_db_password` when applying:
```
export TF_VAR_db_password="$(aws ssm get-parameter --with-decryption --name /kambriq/dev/db/DB_PASSWORD --query Parameter.Value --output text)"
```

## Shell into a running task (ECS Exec)

The bastion was removed. Interactive access to the private subnets is now ECS Exec:

```
TASK="$(aws ecs list-tasks --cluster kambriq-dev-cluster --service-name kambriq-dev-api \
  --query 'taskArns[0]' --output text)"
aws ecs execute-command --cluster kambriq-dev-cluster --task "$TASK" \
  --container api --interactive --command "/bin/sh"
```

Exec only works on tasks started after `enable_ecs_exec` was applied. If a session is
refused, force a new deployment first.

Note: ECS Exec gives a shell inside the container. It does **not** port-forward RDS to a
local machine, which is what the bastion tunnel did. From the container the database is
reachable over the network and the Prisma CLI is available, so `prisma db execute` works.
A local `psql` or GUI session against dev is not currently available.

## GitHub Variables Helper
Use `scripts/set-github-vars.sh` to map Terraform outputs to GitHub environment
variables for CI/CD.

## Deployment Sequence
See `docs/deployment-sequence.md` for the full infra → API → web rollout flow.

## Commit Hygiene
- Do not add `Made-with: Cursor` to commits.
