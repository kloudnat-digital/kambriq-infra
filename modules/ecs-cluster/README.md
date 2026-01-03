# ECS Cluster Module - KAMBRIQ v2.0

Creates an ECS Cluster with CloudWatch Logs and Container Insights.

## Resources Created

- ECS Cluster
- CloudWatch Log Group
- IAM Role for ECS Task Execution (ECR pull, CloudWatch Logs)

## Usage

```hcl
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name = "kambriq"
  env          = "dev"
  
  enable_container_insights = true
  log_retention_days        = 7
}
```

## Outputs

- `cluster_id` - ECS Cluster ID
- `cluster_arn` - ECS Cluster ARN
- `cluster_name` - ECS Cluster name
- `log_group_name` - CloudWatch Log Group name
- `task_execution_role_arn` - ECS Task Execution Role ARN

