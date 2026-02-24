# Application Load Balancer Module - KAMBRIQ v2.0

Creates an Application Load Balancer with routing rules:
- `/api/*` → NestJS API Target Group
- `/*` → Web Target Group

## Resources Created

- Application Load Balancer (Internet-facing)
- Security Group for ALB
- HTTPS Listener (443) with ACM certificate
- HTTP Listener (80) redirecting to HTTPS
- Target Group for API (port 3000, health check `/api/v1/health/ready`)
- Target Group for Next.js (port 3000)
- Listener Rules for routing

## Usage

```hcl
module "alb" {
  source = "../../modules/alb"

  project_name      = "kambriq"
  env               = "dev"
  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  certificate_arn   = var.api_acm_certificate_arn
  
  api_port = 3000
  web_port = 3000
}
```

## Outputs

- `alb_id` - ALB ID
- `alb_arn` - ALB ARN
- `alb_dns_name` - ALB DNS name (for CloudFront origin)
- `alb_zone_id` - ALB hosted zone ID
- `api_target_group_arn` - API Target Group ARN
- `web_target_group_arn` - Next.js Target Group ARN
- `alb_security_group_id` - ALB Security Group ID

