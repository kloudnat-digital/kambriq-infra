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
  # Generate a unique suffix from account ID (hash to avoid exposing account ID in bucket names)
  account_id_hash = substr(md5("${data.aws_caller_identity.current.account_id}-${var.aws_region}"), 0, 8)

  # Availability zones
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
  count  = var.nat_per_az ? length(aws_subnet.public) : 1
  domain = "vpc"

  tags = {
    Name = var.nat_per_az ? "${local.name_prefix}-nat-eip-${count.index + 1}" : "${local.name_prefix}-nat-eip"
    Type = "shared"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (single AZ to reduce costs)
resource "aws_nat_gateway" "main" {
  count         = var.nat_per_az ? length(aws_subnet.public) : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.nat_per_az ? aws_subnet.public[count.index].id : aws_subnet.public[0].id

  tags = {
    Name = var.nat_per_az ? "${local.name_prefix}-nat-${count.index + 1}" : "${local.name_prefix}-nat"
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
  count  = var.nat_per_az ? length(aws_subnet.private) : 1
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_per_az ? aws_nat_gateway.main[count.index].id : aws_nat_gateway.main[0].id
  }

  tags = {
    Name = var.nat_per_az ? "${local.name_prefix}-private-rt-${count.index + 1}" : "${local.name_prefix}-private-rt"
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
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.nat_per_az ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

# ============================================================================
# Route53 Hosted Zone
# ============================================================================
# Route53 hosted zone is created manually in AWS Console.
# Terraform uses a data source to reference the existing zone.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

data "aws_route53_zone" "main" {
  count   = var.enable_route53_lookup && var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
}

data "aws_route53_zone" "main_by_name" {
  count = var.enable_route53_lookup && var.route53_zone_id == "" ? 1 : 0
  name  = var.domain_name
}

locals {
  route53_zone = var.enable_route53_lookup ? (var.route53_zone_id != "" ? data.aws_route53_zone.main[0] : data.aws_route53_zone.main_by_name[0]) : null
}

# ============================================================================
# SES Domain Identity
# ============================================================================
# SES identities (domain/email) are created and verified manually in AWS Console.
# The ARNs and domain/email values are provided via variables.
# No Terraform resources are created here - only outputs are provided based on variables.
# 
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

# ============================================================================
# ACM Certificates
# ============================================================================
# ACM certificates are created and validated manually in AWS Console.
# The ARNs are provided via variables:
# - api_acm_certificate_arn: Certificate for API Gateway (must be in eu-central-1)
# - cloudfront_acm_certificate_arn: Certificate for CloudFront (must be in us-east-1)
# No Terraform resources are created here - only outputs are provided based on variables.
#
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

# ============================================================================
# S3 Buckets for Logs and Artifacts
# ============================================================================

# S3 Bucket for Logs
resource "aws_s3_bucket" "logs" {
  count  = var.enable_s3_logs ? 1 : 0
  bucket = "${local.name_prefix}-logs-${local.account_id_hash}"

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
  bucket = "${local.name_prefix}-artifacts-${local.account_id_hash}"

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

