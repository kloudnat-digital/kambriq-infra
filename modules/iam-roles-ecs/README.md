# IAM Roles for ECS Tasks - KAMBRIQ v2.0

Creates IAM roles for ECS tasks (API and Web) with appropriate permissions.

## Resources Created

- IAM Role for ECS Task (API - FastAPI)
- IAM Role for ECS Task (Web - Next.js)
- Policies for SSM Parameter Store access
- Policy for RDS access (API only)

## Usage

```hcl
module "iam_roles_ecs" {
  source = "../../modules/iam-roles-ecs"

  project_name = "kambriq"
  env          = "dev"
  aws_region   = "eu-central-1"
}
```

## Outputs

- `task_api_role_arn` - IAM Role ARN for ECS Task (API)
- `task_web_role_arn` - IAM Role ARN for ECS Task (Web)

