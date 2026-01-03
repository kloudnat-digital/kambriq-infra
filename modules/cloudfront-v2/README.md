# CloudFront Distribution Module V2 - KAMBRIQ v2.0

Creates a CloudFront distribution with ALB as origin.

## Cache Behaviors

- `/api/*` → ALB (no cache, forward all headers/cookies)
- `/*` → ALB (cache static assets, no cache for SSR)

## Resources Created

- CloudFront Distribution
- Custom origin (ALB)
- Cache behaviors

## Usage

```hcl
module "cloudfront_v2" {
  source = "../../modules/cloudfront-v2"

  project_name = "kambriq"
  env          = "dev"
  alb_dns_name = module.alb.alb_dns_name
  domain_name  = "dev.kambriq.com"
  certificate_arn = var.cloudfront_acm_certificate_arn
}
```

## Outputs

- `distribution_id` - CloudFront Distribution ID
- `distribution_arn` - CloudFront Distribution ARN
- `distribution_domain_name` - CloudFront Distribution domain name
- `distribution_hosted_zone_id` - CloudFront Distribution hosted zone ID

