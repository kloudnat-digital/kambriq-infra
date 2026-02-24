# GitHub Variables Mapping

Use Terraform outputs from `envs/dev` or `envs/prd` to populate
repository or environment variables in GitHub for the deploy workflows.
Apply `envs/shared` first to create the shared VPC/NAT.

## Required GitHub Variables

- `AWS_REGION` → `aws_region` (tfvars)
- `ECR_REPO` → `ecr_api_repository_url`
- `ECS_CLUSTER` → `ecs_cluster_name`
- `ECS_SERVICE` → `ecs_service_api_name`
- `ECS_TASK_DEFINITION` → `ecs_task_definition_arn_api`
- `ECS_SUBNETS` → `private_subnet_ids` (comma-separated)
- `ECS_SECURITY_GROUPS` → `ecs_security_group_id`

Optional:
- `CONTAINER_NAME` → `api`
- `ASSIGN_PUBLIC_IP` → `DISABLED`
- `SMOKE_TEST_URL` → `https://dev.kambriq.com/api/v1/health/ready` (dev)

## Secrets

- `AWS_ROLE_ARN` → IAM role for GitHub OIDC (deploy role)

## Manual setup reminder

These variables and secrets must be configured in GitHub:
- Repo Settings → Environments → `dev`, `prd`

## Helper script

Use the helper to set vars from Terraform outputs:

```
./scripts/set-github-vars.sh dev kloudnat-digital/kambriq-api <AWS_ROLE_ARN>
./scripts/set-github-vars.sh prd kloudnat-digital/kambriq-api <AWS_ROLE_ARN>
```
- Add required vars/secrets per environment
