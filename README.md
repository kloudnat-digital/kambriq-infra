# KAMBRIQ AWS Infrastructure as Code (Terraform)

## Overview
This repository provisions shared AWS infrastructure and environment-specific
workloads for the KAMBRIQ platform using Terraform.

## Environments
Environments live under `envs/`:
- `envs/shared` - VPC, subnets, NAT, Route53 lookups, and shared S3 buckets.
- `envs/dev` - ECS, RDS, Redis, ALB, bastion host, Route53 records, and SSM parameters.
- `envs/prd` - ECS, RDS, Redis, ALB, bastion host, and SSM parameters.

## Remote State
All environments store state in:
- S3 bucket: `kloudnat-infra-shared-store`
- Keys:
  - `kambriq/envs/shared/terraform.tfstate`
  - `kambriq/envs/dev/terraform.tfstate`
  - `kambriq/envs/prd/terraform.tfstate`

## Apply Order
1. `envs/shared`
2. `envs/dev` and/or `envs/prd`

## Bastion Access
- Update `bastion_allowed_ssh_cidrs` in the env `terraform.tfvars` files with
  your IPs before applying.
- Bastion hosts are separated per environment and include SSM access.

## Database Credentials (SSM)
- The RDS master password is stored in SSM at
  `/kambriq/{env}/db/DB_PASSWORD` (SecureString).
- Do not store the real password in git. Use `TF_VAR_db_password` when applying:
```
export TF_VAR_db_password="$(aws ssm get-parameter --with-decryption --name /kambriq/dev/db/DB_PASSWORD --query Parameter.Value --output text)"
```

## Connect to RDS via SSM Port-Forward (dev example)
1. Start the tunnel (keep the session open):
```
aws ssm start-session \
  --target <BASTION_INSTANCE_ID> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters 'host=["<RDS_ENDPOINT_HOST>"],portNumber=["5432"],localPortNumber=["5432"]'
```
2. Connect locally:
```
PGPASSWORD="$(aws ssm get-parameter --with-decryption --name /kambriq/dev/db/DB_PASSWORD --query Parameter.Value --output text)" \
psql -h 127.0.0.1 -p 5432 -U kambriq_admin -d kambriq_core
```

## One-liner: Export DATABASE_URLs via the Tunnel
```
DB_PASS="$(aws ssm get-parameter --with-decryption --name /kambriq/dev/db/DB_PASSWORD --query Parameter.Value --output text)"; \
DB_USER="kambriq_admin"; DB_HOST="127.0.0.1"; DB_PORT="5432"; \
for entry in CORE:kambriq_core KBS:kambriq_kbs; do \
  key="${entry%%:*}"; name="${entry#*:}"; \
  export "DATABASE_URL_${key}=postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${name}?schema=public"; \
done
```
To add future databases, append entries like `KAMNET:<db_name>` or `VERIFY:<db_name>` to the `for entry in ...` list.

## GitHub Variables Helper
Use `scripts/set-github-vars.sh` to map Terraform outputs to GitHub environment
variables for CI/CD.

## Deployment Sequence
See `docs/deployment-sequence.md` for the full infra → API → web rollout flow.
