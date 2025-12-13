variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for Route53 and SES (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

# Route53 Configuration
# Note: Route53 hosted zone is created manually in AWS Console.
# Provide the zone_id here after manual setup.
# See docs/setup/ROUTE53_DNS_SETUP.md for manual setup instructions.

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (created manually in AWS Console, e.g., Z035969434MOMAYZATZ1D)"
  type        = string
  default     = ""
}

# SES Configuration
# Note: SES identities must be created and verified manually in AWS Console.
# After manual setup, provide the ARNs and domain/email values here.
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.

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
  description = "ARN of SES domain identity (created manually in AWS Console, e.g., arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "SES sender email address already verified in AWS Console (e.g., noreply@kambriq.com)"
  type        = string
  default     = "noreply@kambriq.com"
}

variable "ses_email_identity_arn" {
  description = "ARN of SES email identity (created manually in AWS Console, e.g., arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com)"
  type        = string
  default     = ""
}

# ACM Certificate Configuration
# Note: ACM certificates must be created and validated manually in AWS Console.
# After manual setup, provide the ARNs here.
# CloudFront certificates must be created in us-east-1, API Gateway certificates in eu-central-1.
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.

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

# ============================================================================
# Bastion Configuration (shared between dev and prod)
# ============================================================================

variable "enable_bastion" {
  description = "Enable bastion host for manual database migrations (shared between dev and prod)"
  type        = bool
  default     = true
}

variable "bastion_key_pair_name" {
  description = "Name of the existing EC2 Key Pair for SSH access to bastion (must exist in AWS)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "List of CIDR blocks allowed to SSH into the bastion (e.g., ['1.2.3.4/32', '5.6.7.8/32']). Required if enable_bastion = true."
  type        = list(string)
  default     = []

  validation {
    condition     = var.enable_bastion == false || (length(var.allowed_ssh_cidr) > 0 && alltrue([for cidr in var.allowed_ssh_cidr : can(cidrhost(cidr, 0))]))
    error_message = "allowed_ssh_cidr is required when enable_bastion is true. Please provide a non-empty list of valid CIDR blocks (e.g., ['1.2.3.4/32', '5.6.7.8/32'])."
  }
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG (0 to stop bastion, 1 to start)"
  type        = number
  default     = 1
}

variable "asg_desired_size" {
  description = "Desired number of instances in ASG (0 to stop bastion, 1 to start)"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG (should be 1 for bastion)"
  type        = number
  default     = 1
}

