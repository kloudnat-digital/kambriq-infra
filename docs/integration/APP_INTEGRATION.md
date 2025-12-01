# Application Integration Guide

This document explains how the Terraform infrastructure outputs are consumed by the Kambriq application and how CI/CD pipelines should integrate Terraform outputs with application deployments.

## Table of Contents

1. [Overview](#overview)
2. [Terraform Outputs](#terraform-outputs)
3. [Output to Environment Variable Mapping](#output-to-environment-variable-mapping)
4. [SSM Parameter Store Integration](#ssm-parameter-store-integration)
5. [CI/CD Integration](#cicd-integration)
6. [Lambda Environment Variables](#lambda-environment-variables)
7. [Frontend Build Configuration](#frontend-build-configuration)
8. [Best Practices](#best-practices)

## Overview

The Terraform infrastructure generates outputs that must be consumed by:
- **Backend (NestJS API)**: Deployed as AWS Lambda
- **Frontend (Next.js)**: Deployed to S3 and served via CloudFront

Outputs are consumed via:
1. **Direct Terraform outputs**: For non-sensitive values (URLs, bucket names, etc.)
2. **SSM Parameter Store / Secrets Manager**: For sensitive values (passwords, secrets)

## Terraform Outputs

### Available Outputs

Each environment (`dev` and `prod`) exposes the following outputs in `envs/{env}/outputs.tf`:

#### Frontend Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `frontend_url` | Full CloudFront URL | `https://d1234567890.cloudfront.net` |
| `frontend_domain` | CloudFront distribution domain | `d1234567890.cloudfront.net` |

#### API Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `api_url` | Full API Gateway URL | `https://abc123.execute-api.eu-central-1.amazonaws.com` |
| `api_endpoint` | API Gateway endpoint (hostname only) | `abc123.execute-api.eu-central-1.amazonaws.com` |

#### Database Outputs

| Output Name | Description | Example Value | Sensitive |
|-------------|-------------|---------------|-----------|
| `db_host` | RDS endpoint hostname | `kambriq-db-dev.abc123.eu-central-1.rds.amazonaws.com` | No |
| `db_port` | PostgreSQL port | `5432` | No |
| `db_name` | Database name | `kambriq` | No |
| `db_endpoint` | Full endpoint (host:port) | `kambriq-db-dev.abc123.eu-central-1.rds.amazonaws.com:5432` | No |
| `db_username` | Database master username | `kambriq_admin` | **Yes** |

**Note**: `db_password` is NOT exposed as an output. It must be retrieved from SSM Parameter Store or Secrets Manager.

#### S3 Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `s3_media_bucket` | S3 bucket for media uploads | `kambriq-media-dev` |
| `s3_static_bucket` | S3 bucket for static site | `kambriq-static-dev` |

#### SES Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `ses_from_email` | SES sender email address | `noreply@kambriq.com` |
| `ses_identity_arn` | SES email identity ARN | `arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com` |
| `ses_domain_identity_arn` | SES domain identity ARN | `arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com` |
| `ses_domain_verification_token` | DNS verification token | `abc123...` |

#### Lambda Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `lambda_function_name` | Lambda function name | `kambriq-api-dev` |
| `lambda_function_arn` | Lambda function ARN | `arn:aws:lambda:eu-central-1:123456789012:function:kambriq-api-dev` |

### Missing Outputs

The following outputs should be added to `envs/{env}/outputs.tf`:

```hcl
# AWS Region
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
```

## Output to Environment Variable Mapping

### Frontend Mapping

| Terraform Output | Environment Variable | Usage |
|------------------|---------------------|-------|
| `api_url` | `NEXT_PUBLIC_API_BASE_URL` | API endpoint for frontend requests |
| `frontend_url` | `NEXT_PUBLIC_SITE_URL` | Site URL for metadata and links |
| `frontend_domain` | `NEXT_PUBLIC_CLOUDFRONT_DOMAIN` | CloudFront domain for asset delivery |
| `s3_media_bucket` | `NEXT_PUBLIC_S3_BUCKET_NAME` | S3 bucket name for uploads |

### Backend Mapping

| Terraform Output | Environment Variable | Usage |
|------------------|---------------------|-------|
| `db_host` | Part of `DATABASE_URL` | Database connection |
| `db_port` | Part of `DATABASE_URL` | Database connection |
| `db_name` | Part of `DATABASE_URL` | Database connection |
| `db_username` | Part of `DATABASE_URL` | Database connection (from SSM) |
| `db_password` | Part of `DATABASE_URL` | Database connection (from SSM) |
| `s3_media_bucket` | `S3_MEDIA_BUCKET` | S3 bucket for media storage |
| `ses_from_email` | `SES_FROM_EMAIL` / `AWS_SES_FROM_EMAIL` | SES sender email |
| `frontend_url` | `FRONTEND_URL` | CORS origin and email links |
| `aws_region` | `AWS_REGION` | AWS SDK region configuration |

**Note**: `DATABASE_URL` must be constructed as:
```
postgres://{db_username}:{db_password}@{db_host}:{db_port}/{db_name}
```

## SSM Parameter Store Integration

### Required SSM Parameters

Sensitive values must be stored in SSM Parameter Store using the following naming convention:

```
/kambriq/{environment}/{parameter_name}
```

#### Required Parameters

| Parameter Path | Type | Description | Source |
|---------------|------|-------------|--------|
| `/kambriq/{env}/DATABASE_PASSWORD` | SecureString | RDS database password | Terraform variable `db_password` |
| `/kambriq/{env}/JWT_SECRET` | SecureString | JWT signing secret | Terraform variable `jwt_secret` |
| `/kambriq/{env}/DATABASE_URL` | SecureString | Complete PostgreSQL connection string | **Constructed** from outputs + SSM |

### Creating SSM Parameters

After Terraform apply, create SSM parameters:

```bash
# Set environment
ENV=dev  # or prod

# Get Terraform outputs
cd kambriq-aws-iac-terraform/envs/$ENV
terraform output -json > tf-outputs.json

# Store database password (if not already stored)
aws ssm put-parameter \
  --name "/kambriq/$ENV/DATABASE_PASSWORD" \
  --value "$(terraform output -raw db_password)" \
  --type SecureString \
  --overwrite

# Store JWT secret (if not already stored)
aws ssm put-parameter \
  --name "/kambriq/$ENV/JWT_SECRET" \
  --value "$(terraform output -raw jwt_secret)" \
  --type SecureString \
  --overwrite

# Construct and store DATABASE_URL
DB_HOST=$(jq -r '.db_host.value' tf-outputs.json)
DB_PORT=$(jq -r '.db_port.value' tf-outputs.json)
DB_NAME=$(jq -r '.db_name.value' tf-outputs.json)
DB_USERNAME=$(jq -r '.db_username.value' tf-outputs.json)
DB_PASSWORD=$(aws ssm get-parameter --name "/kambriq/$ENV/DATABASE_PASSWORD" --with-decryption --query 'Parameter.Value' --output text)

DATABASE_URL="postgres://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

aws ssm put-parameter \
  --name "/kambriq/$ENV/DATABASE_URL" \
  --value "$DATABASE_URL" \
  --type SecureString \
  --overwrite
```

### Terraform Module for SSM Parameters

Consider creating a Terraform module to manage SSM parameters:

```hcl
# modules/ssm-parameters/main.tf
resource "aws_ssm_parameter" "database_password" {
  name  = "/kambriq/${var.env}/DATABASE_PASSWORD"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/kambriq/${var.env}/JWT_SECRET"
  type  = "SecureString"
  value = var.jwt_secret
}

resource "aws_ssm_parameter" "database_url" {
  name  = "/kambriq/${var.env}/DATABASE_URL"
  type  = "SecureString"
  value = "postgres://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_name}"
}
```

## CI/CD Integration

### GitHub Actions Workflow

#### Step 1: After Terraform Apply

```yaml
- name: Extract Terraform Outputs
  id: terraform-outputs
  run: |
    cd kambriq-aws-iac-terraform/envs/${{ env.ENVIRONMENT }}
    terraform output -json > tf-outputs.json
    
    # Extract outputs as GitHub Actions outputs
    echo "api_url=$(jq -r '.api_url.value' tf-outputs.json)" >> $GITHUB_OUTPUT
    echo "frontend_url=$(jq -r '.frontend_url.value' tf-outputs.json)" >> $GITHUB_OUTPUT
    echo "frontend_domain=$(jq -r '.frontend_domain.value' tf-outputs.json)" >> $GITHUB_OUTPUT
    echo "s3_media_bucket=$(jq -r '.s3_media_bucket.value' tf-outputs.json)" >> $GITHUB_OUTPUT
    echo "ses_from_email=$(jq -r '.ses_from_email.value' tf-outputs.json)" >> $GITHUB_OUTPUT
    echo "aws_region=$(jq -r '.aws_region.value' tf-outputs.json)" >> $GITHUB_OUTPUT
```

#### Step 2: Store Secrets in SSM

```yaml
- name: Store Secrets in SSM
  run: |
    ENV=${{ env.ENVIRONMENT }}
    
    # Store DATABASE_URL (constructed)
    DB_HOST=$(jq -r '.db_host.value' tf-outputs.json)
    DB_PORT=$(jq -r '.db_port.value' tf-outputs.json)
    DB_NAME=$(jq -r '.db_name.value' tf-outputs.json)
    DB_USERNAME=$(jq -r '.db_username.value' tf-outputs.json)
    DB_PASSWORD=$(aws ssm get-parameter --name "/kambriq/$ENV/DATABASE_PASSWORD" --with-decryption --query 'Parameter.Value' --output text)
    
    DATABASE_URL="postgres://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    
    aws ssm put-parameter \
      --name "/kambriq/$ENV/DATABASE_URL" \
      --value "$DATABASE_URL" \
      --type SecureString \
      --overwrite
```

#### Step 3: Deploy Backend (Lambda)

```yaml
- name: Update Lambda Environment Variables
  run: |
    ENV=${{ env.ENVIRONMENT }}
    FUNCTION_NAME=$(jq -r '.lambda_function_name.value' tf-outputs.json)
    
    # Get secrets from SSM
    DATABASE_URL=$(aws ssm get-parameter --name "/kambriq/$ENV/DATABASE_URL" --with-decryption --query 'Parameter.Value' --output text)
    JWT_SECRET=$(aws ssm get-parameter --name "/kambriq/$ENV/JWT_SECRET" --with-decryption --query 'Parameter.Value' --output text)
    
    # Get non-sensitive values from Terraform
    S3_MEDIA_BUCKET=$(jq -r '.s3_media_bucket.value' tf-outputs.json)
    SES_FROM_EMAIL=$(jq -r '.ses_from_email.value' tf-outputs.json)
    FRONTEND_URL=$(jq -r '.frontend_url.value' tf-outputs.json)
    AWS_REGION=$(jq -r '.aws_region.value' tf-outputs.json)
    
    # Update Lambda environment variables
    aws lambda update-function-configuration \
      --function-name "$FUNCTION_NAME" \
      --environment "Variables={
        DATABASE_URL=$DATABASE_URL,
        JWT_SECRET=$JWT_SECRET,
        AWS_REGION=$AWS_REGION,
        S3_MEDIA_BUCKET=$S3_MEDIA_BUCKET,
        SES_FROM_EMAIL=$SES_FROM_EMAIL,
        AWS_SES_FROM_EMAIL=$SES_FROM_EMAIL,
        FRONTEND_URL=$FRONTEND_URL,
        NODE_ENV=$ENV
      }"
```

#### Step 4: Deploy Frontend (S3 + CloudFront)

```yaml
- name: Build Frontend with Environment Variables
  run: |
    cd kambriq/web
    
    # Create .env.local from Terraform outputs
    echo "NEXT_PUBLIC_API_BASE_URL=${{ steps.terraform-outputs.outputs.api_url }}" >> .env.local
    echo "NEXT_PUBLIC_SITE_URL=${{ steps.terraform-outputs.outputs.frontend_url }}" >> .env.local
    echo "NEXT_PUBLIC_CLOUDFRONT_DOMAIN=${{ steps.terraform-outputs.outputs.frontend_domain }}" >> .env.local
    echo "NEXT_PUBLIC_S3_BUCKET_NAME=${{ steps.terraform-outputs.outputs.s3_media_bucket }}" >> .env.local
    echo "NEXT_PUBLIC_ENVIRONMENT=${{ env.ENVIRONMENT }}" >> .env.local
    
    # Build Next.js app
    pnpm build
    
    # Export static site
    pnpm export
    
- name: Deploy to S3
  run: |
    S3_BUCKET=$(jq -r '.s3_static_bucket.value' tf-outputs.json)
    aws s3 sync kambriq/web/out s3://$S3_BUCKET --delete
    
- name: Invalidate CloudFront Cache
  run: |
    DISTRIBUTION_ID=$(jq -r '.distribution_id.value' tf-outputs.json)
    aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
```

## Lambda Environment Variables

### Current Lambda Configuration

The Lambda function is configured with environment variables in `modules/lambda-api/main.tf`:

```hcl
environment {
  variables = {
    NODE_ENV        = var.env
    DB_HOST         = var.db_host
    DB_PORT         = tostring(var.db_port)
    DB_NAME         = var.db_name
    DB_USERNAME     = var.db_username
    DB_PASSWORD     = var.db_password
    S3_MEDIA_BUCKET = var.s3_media_bucket
    SES_FROM_EMAIL  = var.ses_from_email
    JWT_SECRET      = var.jwt_secret
  }
}
```

### Recommended Updates

1. **Add `DATABASE_URL`**: Prisma requires `DATABASE_URL`, not individual DB components
2. **Add `AWS_REGION`**: Required for AWS SDK
3. **Add `FRONTEND_URL`**: Required for CORS and email links
4. **Move secrets to SSM**: `DB_PASSWORD` and `JWT_SECRET` should be retrieved from SSM at runtime or during deployment

### Updated Lambda Module

```hcl
# In modules/lambda-api/main.tf
environment {
  variables = {
    NODE_ENV        = var.env
    DATABASE_URL    = var.database_url  # Constructed from components
    AWS_REGION      = var.aws_region
    S3_MEDIA_BUCKET = var.s3_media_bucket
    SES_FROM_EMAIL  = var.ses_from_email
    AWS_SES_FROM_EMAIL = var.ses_from_email
    FRONTEND_URL    = var.frontend_url
    # JWT_SECRET should be retrieved from SSM at runtime or set during deployment
  }
}
```

## Frontend Build Configuration

### Next.js Environment Variables

Next.js requires environment variables to be prefixed with `NEXT_PUBLIC_` to be accessible in the browser.

### Build-Time Injection

Environment variables must be set **before** running `next build`:

```bash
export NEXT_PUBLIC_API_BASE_URL=https://api-dev.kambriq.com
export NEXT_PUBLIC_SITE_URL=https://app-dev.kambriq.com
export NEXT_PUBLIC_CLOUDFRONT_DOMAIN=d1234567890.cloudfront.net
export NEXT_PUBLIC_S3_BUCKET_NAME=kambriq-media-dev
export NEXT_PUBLIC_ENVIRONMENT=development

pnpm build
```

### Static Export

For static export (S3 deployment), use:

```bash
pnpm build
pnpm export  # or next export
```

The environment variables are baked into the static files during build.

## Best Practices

### 1. Never Expose Secrets in Terraform Outputs

- ❌ **DO NOT** output passwords or secrets
- ✅ **DO** mark sensitive outputs with `sensitive = true`
- ✅ **DO** store secrets in SSM Parameter Store / Secrets Manager

### 2. Use SSM Parameter Store for Secrets

- Store `DATABASE_PASSWORD` in SSM (SecureString)
- Store `JWT_SECRET` in SSM (SecureString)
- Store `DATABASE_URL` in SSM (SecureString) after construction

### 3. Construct DATABASE_URL in CI/CD

The `DATABASE_URL` should be constructed in the CI/CD pipeline, not in Terraform, to avoid exposing the password in Terraform state.

### 4. Update Lambda Environment Variables After Deployment

After deploying new Lambda code, update environment variables to ensure they match the latest Terraform outputs.

### 5. Version Control for Environment Files

- ✅ **DO** commit `.env.example` files with placeholder values
- ❌ **DO NOT** commit `.env` or `.env.local` files with real values
- ✅ **DO** document the mapping in `ENVIRONMENT_VARIABLES.md`

### 6. IAM Permissions

Ensure the CI/CD pipeline has permissions to:
- Read Terraform outputs (if stored in S3 backend)
- Read/write SSM parameters: `/kambriq/{env}/*`
- Update Lambda function configuration
- Deploy to S3 and invalidate CloudFront

### 7. Environment-Specific Configuration

Use separate Terraform workspaces or directories for each environment:
- `envs/dev/` - Development environment
- `envs/prod/` - Production environment
- `envs/shared/` - Shared resources (VPC, Route53, SES domain)

## Troubleshooting

### Missing Terraform Outputs

If an output is missing:

1. Check `envs/{env}/outputs.tf` for the output definition
2. Verify the module outputs the value in `modules/{module}/outputs.tf`
3. Run `terraform refresh` and `terraform output` to verify

### Lambda Cannot Access Database

1. Verify Lambda is in the correct VPC and subnets
2. Check RDS security group allows Lambda security group
3. Verify `DATABASE_URL` is correctly constructed
4. Check Lambda IAM role has VPC permissions

### Frontend Cannot Call API

1. Verify `NEXT_PUBLIC_API_BASE_URL` is set correctly
2. Check API Gateway CORS configuration
3. Verify `FRONTEND_URL` in Lambda matches the frontend URL
4. Check API Gateway integration with Lambda

## Phase 2 – CloudFront Routing `/api/*` to API Gateway (TODO)

### Current State

Currently, CloudFront only serves the frontend from S3. API Gateway is accessed directly via its endpoint URL, not through CloudFront.

**Current Architecture** :
```
Navigateur → CloudFront → S3 (frontend uniquement)
           → API Gateway (accès direct, pas via CloudFront)
```

### Target Architecture (MVP)

**Target Architecture** :
```
Navigateur → CloudFront → S3 (frontend)
           → CloudFront → /api/* → API Gateway → Lambda
```

### Required Changes

#### 1. Update CloudFront Module

**File** : `modules/cloudfront/main.tf`

Add API Gateway as an origin and create a cache behavior for `/api/*`:

```hcl
# Add variable for API Gateway endpoint
variable "api_gateway_endpoint" {
  description = "API Gateway HTTP API endpoint (e.g., abc123.execute-api.eu-central-1.amazonaws.com)"
  type        = string
  default     = ""
}

# Add origin for API Gateway (if endpoint provided)
origin {
  domain_name = var.api_gateway_endpoint
  origin_id   = "API-Gateway-${var.env}"
  
  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}

# Add cache behavior for /api/* (before default_cache_behavior)
ordered_cache_behavior {
  path_pattern     = "/api/*"
  allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  cached_methods   = ["GET", "HEAD"]
  target_origin_id = "API-Gateway-${var.env}"
  
  forwarded_values {
    query_string = true
    headers      = ["Authorization", "Content-Type", "X-Requested-With"]
    cookies {
      forward = "all"
    }
  }
  
  viewer_protocol_policy = "redirect-to-https"
  min_ttl                = 0
  default_ttl             = 0  # No cache for API responses
  max_ttl                 = 0
  compress                = true
}
```

#### 2. Update Environment Configurations

**Files** : `envs/dev/main.tf`, `envs/prod/main.tf`

Pass the API Gateway endpoint to the CloudFront module:

```hcl
module "cloudfront" {
  source = "../../modules/cloudfront"

  env                            = local.env
  s3_bucket_id                   = module.s3_static.bucket_id
  s3_bucket_regional_domain_name = module.s3_static.bucket_regional_domain_name
  domain_name                    = var.cloudfront_domain != "" ? var.cloudfront_domain : ""
  certificate_arn                = var.cloudfront_certificate_arn != "" ? var.cloudfront_certificate_arn : ""
  api_gateway_endpoint           = module.api_gateway.api_endpoint  # Add this line
}
```

#### 3. Update CloudFront Outputs

**File** : `modules/cloudfront/outputs.tf`

Add the hosted zone ID for Route53 records:

```hcl
output "distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID (for Route53 alias records)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}
```

### Benefits

- ✅ Single entry point (same domain for frontend and API)
- ✅ Simplified CORS configuration
- ✅ Edge caching capabilities (if needed)
- ✅ Consistent domain for cookies and authentication

### Notes

- The cache behavior for `/api/*` should have `default_ttl = 0` to avoid caching API responses
- All query strings and necessary headers (Authorization, Content-Type) must be forwarded
- Cookies must be forwarded for authentication to work

### Related Documentation

- [Terraform Current State](../architecture/TERRAFORM_CURRENT_STATE.md) - Detailed comparison with target architecture
- [Phase 2 Documentation](../phase-2/phase-2.md) - Alternative architecture with direct `api.kambriq.com`

## Related Documentation

- [Environment Variables Documentation](../../kambriq/docs/configuration/ENVIRONMENT_VARIABLES.md) - Complete mapping and usage guide
- [Lambda Deployment Guide](../../kambriq/docs/deployment/lambda-deployment.md) - Backend deployment details
- [Frontend S3/CloudFront Deployment](../../kambriq/docs/deployment/frontend-s3-cloudfront.md) - Frontend deployment details
- [Terraform Current State](../architecture/TERRAFORM_CURRENT_STATE.md) - Current architecture state vs target

