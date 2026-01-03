# ECS Service Module - KAMBRIQ v2.0

Creates an ECS Task Definition and Service for a single application.

## Resources Created

- CloudWatch Log Group
- ECS Task Definition
- ECS Service

## Usage

```hcl
module "ecs_service_api" {
  source = "../../modules/ecs-service"

  project_name            = "kambriq"
  env                     = "dev"
  service_name            = "api"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.iam_roles_ecs.task_api_role_arn
  container_image         = "${module.ecr_api.repository_url}:latest"
  container_port          = 8000
  cpu                     = 256
  memory                  = 512
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.api_target_group_arn
  assign_public_ip        = false
  
  environment_variables = {
    ENV = "dev"
  }
  
  secrets = {
    DATABASE_URL = "arn:aws:ssm:eu-central-1:xxx:parameter/kambriq/dev/db/url"
  }
}
```

## Outputs

- `service_id` - ECS Service ID
- `service_name` - ECS Service name
- `task_definition_arn` - ECS Task Definition ARN

