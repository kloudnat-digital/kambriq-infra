# KAMBRIQ AWS Infrastructure as Code (Terraform)

## Overview
This repository provisions shared AWS infrastructure and environment-specific
workloads for the KAMBRIQ platform using Terraform.

## Environments
Environments live under `envs/`:
- `envs/shared` - VPC, subnets, NAT, Route53 lookups, and shared S3 buckets.
- `envs/dev` - ECS, RDS, Redis, ALB, and SSM parameters for development.
- `envs/prd` - ECS, RDS, Redis, ALB, and SSM parameters for production.

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

## GitHub Variables Helper
Use `scripts/set-github-vars.sh` to map Terraform outputs to GitHub environment
variables for CI/CD.
