variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "kambriq"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "shared"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "github_repo_infra" {
  description = "GitHub org/repo for infra Actions OIDC (e.g. org/repo)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = []
}

variable "nat_per_az" {
  description = "Create one NAT Gateway per AZ"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "kambriq.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (manual)"
  type        = string
  default     = ""
}

variable "enable_route53_lookup" {
  description = "Enable Route53 hosted zone lookup"
  type        = bool
  default     = true
}

variable "ses_domain" {
  description = "SES domain"
  type        = string
  default     = "kambriq.com"
}

variable "ses_from_email" {
  description = "SES from email"
  type        = string
  default     = "noreply@kambriq.com"
}

variable "ses_domain_identity_arn" {
  description = "SES domain identity ARN (manual)"
  type        = string
  default     = ""
}

variable "ses_email_identity_arn" {
  description = "SES email identity ARN (manual)"
  type        = string
  default     = ""
}

variable "api_acm_certificate_arn" {
  description = "ACM cert ARN for ALB (eu-central-1)"
  type        = string
  default     = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM cert ARN for CloudFront (us-east-1)"
  type        = string
  default     = ""
}

variable "enable_s3_logs" {
  description = "Enable S3 logs bucket"
  type        = bool
  default     = true
}

variable "enable_s3_artifacts" {
  description = "Enable S3 artifacts bucket"
  type        = bool
  default     = true
}
