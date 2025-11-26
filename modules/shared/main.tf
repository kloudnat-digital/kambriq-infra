# ============================================================================
# Shared Infrastructure Module
# ============================================================================
# This module creates shared resources used by all environments:
# - VPC with public/private subnets + NAT Gateway
# - Route53 hosted zone
# - SES domain identity
# - ACM certificates (CloudFront + API Gateway)
# - S3 buckets for logs and artifacts
# ============================================================================

locals {
  name_prefix = var.project_name
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
}

# ============================================================================
# VPC & Networking
# ============================================================================

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
    Type = "shared"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
    Type = "shared"
  }
}

# Public Subnets (for NAT Gateway and future public resources)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "shared"
  }
}

# Private Subnets (for RDS, Lambda)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "shared"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
    Type = "shared"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (single AZ to reduce costs)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${local.name_prefix}-nat"
    Type = "shared"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
    Type = "shared"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
    Type = "shared"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================================================
# Route53 Hosted Zone
# ============================================================================

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${local.name_prefix}-zone"
    Type = "shared"
  }
}

# ============================================================================
# SES Domain Identity
# ============================================================================

resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# Domain Identity Verification
resource "aws_ses_domain_identity_verification" "main" {
  domain = aws_ses_domain_identity.main.id

  timeouts {
    create = "5m"
  }
}

# Email Identity
resource "aws_ses_email_identity" "main" {
  email = var.ses_from_email
}

# DKIM Configuration
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# ============================================================================
# ACM Certificates
# ============================================================================
# Note: CloudFront certificates must be in us-east-1, but we'll create them
# in the main region for now. The root module will need to handle us-east-1
# separately if needed. For simplicity, we create both in the main region.
# If CloudFront custom domain is needed, create the certificate manually
# in us-east-1 or use a separate provider configuration in the root module.

# Certificate for API Gateway (in the main region)
resource "aws_acm_certificate" "api" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  subject_alternative_names = [var.domain_name]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-api-cert"
    Type = "shared"
  }
}

# DNS Validation Records for API Certificate
resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# Certificate Validation for API
resource "aws_acm_certificate_validation" "api" {
  certificate_arn = aws_acm_certificate.api.arn
  validation_record_fqdns = [
    for record in aws_route53_record.api_cert_validation : record.fqdn
  ]

  timeouts {
    create = "5m"
  }
}

# ============================================================================
# S3 Buckets for Logs and Artifacts
# ============================================================================

# S3 Bucket for Logs
resource "aws_s3_bucket" "logs" {
  count  = var.enable_s3_logs ? 1 : 0
  bucket = "${local.name_prefix}-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.name_prefix}-logs"
    Type = "shared"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  count  = var.enable_s3_logs ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.enable_s3_logs ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket for Artifacts
resource "aws_s3_bucket" "artifacts" {
  count  = var.enable_s3_artifacts ? 1 : 0
  bucket = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.name_prefix}-artifacts"
    Type = "shared"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count  = var.enable_s3_artifacts ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count  = var.enable_s3_artifacts ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

