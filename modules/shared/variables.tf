variable "project_name" {
  description = "Project name (e.g., kambriq)"
  type        = string
  default     = "kambriq"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "nat_per_az" {
  description = "Create one NAT Gateway per AZ"
  type        = bool
  default     = false
}

# Route53 Configuration
# Note: Route53 hosted zone is created manually in AWS Console.
# Provide the zone_id here after manual setup.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

variable "domain_name" {
  description = "Domain name for Route53 hosted zone (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (created manually in AWS Console, e.g., Z035969434MOMAYZATZ1D)"
  type        = string
  default     = ""
}

variable "enable_route53_lookup" {
  description = "Enable Route53 hosted zone lookup"
  type        = bool
  default     = true
}

# SES Configuration
# Note: SES identities (domain/email) must be created and verified manually in AWS Console.
# Provide the ARNs and domain/email values here after manual setup.
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

variable "ses_domain" {
  description = "SES domain already verified in AWS Console (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

variable "ses_region" {
  description = "AWS region where SES identities are created (e.g., eu-central-1)"
  type        = string
  default     = "eu-central-1"
}

variable "ses_domain_identity_arn" {
  description = "ARN of SES domain identity (created manually in AWS Console)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "SES sender email address already verified in AWS Console (e.g., noreply@kambriq.com)"
  type        = string
  default     = "noreply@kambriq.com"
}

# ACM Certificate Configuration
# Note: ACM certificates must be created and validated manually in AWS Console.
# Provide the ARNs here after manual setup.
# CloudFront certificates must be created in us-east-1, API Gateway certificates in eu-central-1.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

variable "api_acm_certificate_arn" {
  description = "ACM certificate ARN for API Gateway (created manually in AWS Console, must be in eu-central-1)"
  type        = string
  default     = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (created manually in AWS Console, must be in us-east-1)"
  type        = string
  default     = ""
}

# S3 Logs Configuration
variable "enable_s3_logs" {
  description = "Enable S3 bucket for logs"
  type        = bool
  default     = true
}

variable "enable_s3_artifacts" {
  description = "Enable S3 bucket for artifacts"
  type        = bool
  default     = true
}


variable "enable_nat" {
  description = <<-EOT
    Whether the private subnets get a NAT gateway.

    D15: with the Fargate tasks moved to the public subnets and
    `assign_public_ip = true`, nothing in the private subnets needs outbound
    internet any more - only RDS and ElastiCache remain there, and neither
    makes an outbound call. The gateway was the largest single line in the dev
    bill, larger than the Fargate compute it served.

    Set to false only when every task that needs egress is in a public subnet.
    A task left in a private subnet with this false cannot pull its image and
    the deploy fails at task start, which is loud rather than silent.
  EOT
  type        = bool
  default     = true
}
