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

## Terraform outputs reference

After `terraform apply`, use these outputs to populate GitHub env vars:

- `ecr_api_repository_url` → `ECR_REPO`
- `ecs_cluster_name` → `ECS_CLUSTER`
- `ecs_service_api_name` → `ECS_SERVICE`
- `ecs_task_definition_arn_api` → `ECS_TASK_DEFINITION`
- `private_subnet_ids` → `ECS_SUBNETS` (comma-separated)
- `ecs_security_group_id` → `ECS_SECURITY_GROUPS`

Example command:

```
AWS_REGION=$(awk -F'=' '/^aws_region/ { gsub(/["[:space:]]/, "", $2); print $2 }' envs/dev/terraform.tfvars)
terraform -chdir=envs/dev output -json | jq -r --arg REGION "$AWS_REGION" '
  "AWS_REGION=" + $REGION,
  "ECR_REPO=" + .ecr_api_repository_url.value,
  "ECS_CLUSTER=" + .ecs_cluster_name.value,
  "ECS_SERVICE=" + .ecs_service_api_name.value,
  "ECS_TASK_DEFINITION=" + .ecs_task_definition_arn_api.value,
  "ECS_SUBNETS=" + (.private_subnet_ids.value | join(",")),
  "ECS_SECURITY_GROUPS=" + .ecs_security_group_id.value
'
```
- Add required vars/secrets per environment
