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

variable "api_acm_certificate_arn" {
  description = "ACM cert ARN for ALB (eu-central-1)"
  type        = string
  default     = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM cert ARN for CloudFront (us-east-1)"
  type        = string
  default     = ""

  # A placeholder is worse than an empty value, and this one proved it.
  #
  # `arn:aws:acm:...:ACCOUNT:certificate/XXXXXXXX` sat here from May. It failed
  # pull request #10's plan with "is an invalid ARN: invalid account ID value",
  # the pull request merged anyway because nothing was required, and it has been
  # in the tree ever since. It looks configured. It is not, and nothing notices
  # because no distribution consumes it yet - so it would have failed on the day
  # somebody added one, which is the worst possible day to discover it.
  #
  # Empty means "not configured", which is honest and already handled. A value
  # shaped like a real ARN and containing none of a real ARN's information is a
  # claim that is false, and that is what this refuses.
  validation {
    condition = var.cloudfront_acm_certificate_arn == "" || !can(regex(
      "ACCOUNT|XXXX|EXAMPLE|TODO|CHANGEME|<[^>]+>", var.cloudfront_acm_certificate_arn
    ))
    error_message = <<-EOT
      cloudfront_acm_certificate_arn looks like a placeholder rather than a real ARN.

      Either set it to the real certificate ARN from us-east-1, or leave it
      empty. Empty is a supported state and means no CloudFront certificate is
      configured; a placeholder means the plan will fail the day a distribution
      is added, and it will not be obvious why.
    EOT
  }

  # The same refusal for a value that is not an ARN at all, which is how this
  # first surfaced: the plan failed inside the ALB module rather than here,
  # naming a resource rather than the variable that fed it.
  validation {
    condition = var.cloudfront_acm_certificate_arn == "" || can(regex(
      "^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[0-9a-f-]+$", var.cloudfront_acm_certificate_arn
    ))
    error_message = "cloudfront_acm_certificate_arn must be a full ACM certificate ARN with a 12-digit account id, or empty."
  }
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

variable "enable_nat_gateway" {
  description = "D15: false removes the NAT gateway and its EIP. Only safe once every task needing egress runs in a public subnet."
  type        = bool
  default     = true
}
