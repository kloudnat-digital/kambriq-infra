# Application Integration Guide

**⚠️ Important** : Ce document explique comment l'infrastructure Terraform et l'application Kambriq s'intègrent. Depuis 2025-12-07, les déploiements applicatifs (mise à jour du code API + Web) sont gérés par les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`, et non plus par Terraform.

Ce document explique :
- Comment les outputs Terraform sont utilisés par l'application
- Comment les secrets sont gérés via SSM Parameter Store
- Comment les workflows de déploiement applicatif interagissent avec l'infrastructure

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
- **Frontend (Next.js)**: Deployed to S3 (static assets) and Lambda SSR (server-side rendering) via CloudFront

### CloudFront Routing Architecture

The CloudFront distribution uses a **dual-origin architecture** for OpenNext:

**Request Flow for `https://dev.kambriq.com/`:**
```
DNS (dev.kambriq.com) 
  → CloudFront Distribution (E9V3S1IFEYPUP)
    → Default Cache Behavior
      → Origin: Lambda Function URL (SSR)
        → Lambda Function (kambriq-frontend-dev-ssr)
          → Handler: .open-next/server-functions/default/index.handler
            → OpenNext index.mjs
              → Next.js App Router (SSR)
                → Returns HTML response
```

1. **Lambda Function URL (SSR Origin)** - Default behavior for all routes:
   - Handles all page requests (including `/`)
   - Handles API routes and dynamic content
   - **Authorization**: `NONE` (access restricted via Lambda permission with CloudFront source ARN)
   - **Invoke Mode**: `BUFFERED` (default, compatible with OpenNext `streaming: false`)
   - No caching (dynamic content)
   - **Handler**: `.open-next/server-functions/default/index.handler` pointing to `index.mjs` in the bundle

2. **S3 Bucket (Static Assets Origin)** - Ordered cache behaviors:
   - `/_next/static/*` - Next.js static assets (cached 1 year)
   - `/assets/*` - Application static assets (cached 1 year)
   - Uses OAC for secure access

**Important**: 
- There is no `default_root_object = "index.html"` because OpenNext SSR handles all routes dynamically via Lambda, including the root path.
- OpenNext is configured with `streaming: false` to match Lambda Function URL's default `BUFFERED` invoke mode. If streaming is enabled, the Function URL must use `invoke_mode = "RESPONSE_STREAM"`.

Outputs are consumed via:
1. **Direct Terraform outputs**: For non-sensitive values (URLs, bucket names, etc.)
2. **SSM Parameter Store / Secrets Manager**: For sensitive values (passwords, secrets)

## Terraform Outputs

### Available Outputs

Each environment (`dev` and `prod`) exposes the following outputs in `envs/{env}/outputs.tf`:

#### Frontend Outputs

| Output Name | Description | Example Value |
|-------------|-------------|---------------|
| `frontend_url` | Full CloudFront URL | `https://d1234567890.cloudfront.net` or `https://dev.kambriq.com` |
| `frontend_domain` | CloudFront distribution domain | `d1234567890.cloudfront.net` or `dev.kambriq.com` |

**CloudFront Aliases**: Les alias CloudFront (`dev.kambriq.com` en dev, `kambriq.com` en prod) sont gérés par Terraform via la variable `cloudfront_domain` dans `envs/dev/main.tf` et `envs/prod/main.tf`. Toute modification des domaines front doit se faire dans ces fichiers et appliquée via `terraform plan` / `terraform apply`.

**Bundle SSR OpenNext**: Le zip déployé pour la Lambda SSR contient `.open-next/` à la racine, avec handler `.open-next/server-functions/default/index.handler`.

**Optimisation d’images**: L’optimisation d’images OpenNext via Lambda est désactivée (`imageOptimization.lambda = false`) pour rester sous la limite Lambda 250MB. Les images sont servies telles quelles depuis S3/CloudFront. Si besoin de réactiver l’optimisation, il faudra remettre `lambda: true` et/ou basculer sur un déploiement Lambda container (ECR) pour absorber la taille.

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
| `verify_store_bucket_name` | S3 bucket for verification documents | `kambriq-verify-store-dev` |

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

**⚠️ Important** : Les secrets applicatifs sont stockés dans SSM Parameter Store et lus au runtime par l'application. Terraform ne gère que l'infrastructure, pas les secrets applicatifs.

### Structure de Paths SSM

Les secrets sont stockés avec la structure suivante :

```
/kambriq/{dev|prod}/{api|web}/{parameter_name}
```

### Required SSM Parameters

**Paramètres SSM obligatoires (par environnement)** :

Pour chaque environnement (dev, prod), les paramètres suivants sont **obligatoires** :

1. **`/kambriq/{env}/db/password`** – `SecureString` – Mot de passe RDS (requis par Terraform, doit être créé manuellement avant le premier `terraform apply`)
2. **`/kambriq/{env}/api/DATABASE_URL`** – `SecureString` – URL PostgreSQL complète (créé automatiquement par Terraform)
3. **`/kambriq/{env}/api/JWT_SECRET`** – `SecureString` – Secret JWT (créé automatiquement par Terraform)
4. **`/kambriq/{env}/api/FRONTEND_URL`** – `String` – URL frontend (créé automatiquement par Terraform)
5. **`/kambriq/{env}/api/SES_FROM_EMAIL`** – `String` – Adresse expéditeur SES (créé automatiquement par Terraform)

**Note importante** :
- Le paramètre `/kambriq/{env}/db/password` doit être créé **manuellement** avant le premier `terraform apply`.
- Les 4 paramètres `/kambriq/{env}/api/*` sont **créés automatiquement par Terraform** via le module `ssm-app-parameters`.
- Ces paramètres sont **vérifiés automatiquement** par `check-ssm-params.js` avant un déploiement applicatif.

#### Secrets API (créés automatiquement par Terraform)

| Parameter Path | Type | Description | Source |
|---------------|------|-------------|--------|
| `/kambriq/{env}/api/DATABASE_URL` | SecureString | Complete PostgreSQL connection string | ✅ Créé par Terraform (module `ssm-app-parameters`) depuis RDS outputs |
| `/kambriq/{env}/api/JWT_SECRET` | SecureString | JWT signing secret | ✅ Créé par Terraform (depuis `/kambriq/{env}/api/jwt_secret` ou placeholder) |
| `/kambriq/{env}/api/FRONTEND_URL` | String | Frontend URL (pour CORS et emails) | ✅ Créé par Terraform depuis CloudFront output |
| `/kambriq/{env}/api/SES_FROM_EMAIL` | String | SES sender email | ✅ Créé par Terraform depuis `var.ses_from_email` |

#### Secrets Web (optionnel, pour runtime SSR)

| Parameter Path | Type | Description | Source |
|---------------|------|-------------|--------|
| `/kambriq/{env}/web/...` | String/SecureString | Configuration runtime SSR (si nécessaire) | Selon besoins |

**Note** : Le Web utilise principalement des variables build-time (`NEXT_PUBLIC_*`) fournies par GitHub Actions. SSM est utilisé uniquement pour des valeurs runtime SSR si nécessaire.

### Creating SSM Parameters

**⚠️ Important** : 
- Le paramètre `/kambriq/{env}/db/password` doit être créé **manuellement** avant le premier `terraform apply`.
- Les 4 paramètres `/kambriq/{env}/api/*` sont créés **automatiquement par Terraform** via le module `ssm-app-parameters` lors du `terraform apply`.

#### Création manuelle du paramètre db/password (requis avant terraform apply)

```bash
# Set environment
ENV=dev  # or prod

# Créer le paramètre db/password (requis avant terraform apply)
# ⚠️ IMPORTANT : Le mot de passe RDS ne peut contenir que des caractères ASCII imprimables
# sauf '/', '@', '"' (guillemets doubles) et ' ' (espace)
# Exemples valides : "KambriqDev2024!Secure", "Prod-DB-Pass-123-ABC"
# Exemples invalides : "pass@word" (contient @), "pass/word" (contient /), "pass word" (contient espace)
DB_PASSWORD="your-secure-password"  # Générer un mot de passe fort (sans /, @, ", espace)
aws ssm put-parameter \
  --name "/kambriq/$ENV/db/password" \
  --value "$DB_PASSWORD" \
  --type SecureString \
  --overwrite \
  --region eu-central-1

# Les 4 paramètres /kambriq/{env}/api/* seront créés automatiquement par Terraform
# lors du terraform apply via le module ssm-app-parameters

# Store SES_FROM_EMAIL (depuis Terraform output)
SES_FROM_EMAIL=$(jq -r '.ses_from_email.value' tf-outputs.json)
aws ssm put-parameter \
  --name "/kambriq/$ENV/api/SES_FROM_EMAIL" \
  --value "$SES_FROM_EMAIL" \
  --type String \
  --overwrite
```

### Chargement au Runtime

**API (Lambda)** : L'API lit automatiquement depuis SSM au démarrage via `api/src/infrastructure/config/config-loader.ts` :
- Détecte l'environnement via `KAMBRIQ_ENV` (dev/prod)
- Lit depuis `/kambriq/{env}/api/...`
- Injecte dans `process.env`
- En local : utilise `.env` (fichier local, non commité)

**Web (SSR)** : Optionnel, via `web/src/lib/runtimeConfig.ts` si nécessaire :
- Build-time : variables `NEXT_PUBLIC_*` via GitHub Actions (non sensibles)
- Runtime SSR : peut lire depuis SSM si nécessaire (cache singleton)

## CI/CD Integration

**⚠️ Important** : Depuis 2025-12-07, les déploiements applicatifs sont gérés par les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`. Ces workflows effectuent directement :
- Build API + Web
- Update Lambda code (`aws lambda update-function-code`)
- Sync S3 assets
- Invalidate CloudFront

Les secrets applicatifs sont lus depuis SSM Parameter Store au runtime par l'application (voir sections ci-dessous).

### Workflows de Déploiement Applicatif

#### `deploy-app-dev.yml` et `deploy-app-prod.yml`

Ces workflows dans le repository `kambriq` effectuent :

1. **Build API** :
   - Install dependencies
   - Generate Prisma client
   - Build NestJS
   - Package en ZIP (dist, node_modules, prisma, package.json)

2. **Build Web** :
   - Install dependencies
   - Build OpenNext
   - Package SSR bundle

3. **Update Lambda API** :
   ```bash
   aws lambda update-function-code \
     --function-name "$API_LAMBDA_NAME" \
     --zip-file "fileb://api-bundle.zip"
   ```

4. **Update Lambda SSR** :
   ```bash
   aws lambda update-function-code \
     --function-name "$WEB_SSR_LAMBDA_NAME" \
     --zip-file "fileb://web-ssr-bundle.zip"
   ```

5. **Sync S3 Assets** :
   ```bash
   aws s3 sync .open-next/assets "s3://$WEB_ASSETS_BUCKET/assets" --delete
   ```

6. **Invalidate CloudFront** :
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
     --paths "/*"
   ```

**Secrets requis** (dans le repository `kambriq`) :
- `AWS_ACCESS_KEY_ID_DEV` / `AWS_ACCESS_KEY_ID_PROD`
- `AWS_SECRET_ACCESS_KEY_DEV` / `AWS_SECRET_ACCESS_KEY_PROD`
- `AWS_REGION_DEV` / `AWS_REGION_PROD`
- `API_LAMBDA_NAME_DEV` / `API_LAMBDA_NAME_PROD`
- `WEB_SSR_LAMBDA_NAME_DEV` / `WEB_SSR_LAMBDA_NAME_PROD`
- `WEB_ASSETS_BUCKET_DEV` / `WEB_ASSETS_BUCKET_PROD`
- `CLOUDFRONT_DISTRIBUTION_ID_DEV` / `CLOUDFRONT_DISTRIBUTION_ID_PROD`

## Lambda Environment Variables

**⚠️ Important** : Les secrets applicatifs ne sont **pas** stockés dans les variables d'environnement Lambda. Ils sont lus depuis SSM Parameter Store au runtime par l'application.

### Configuration Lambda (Terraform)

Les Lambda functions sont créées par Terraform avec des variables d'environnement minimales (non sensibles) :

```hcl
# In modules/lambda-api/main.tf
environment {
  variables = {
    NODE_ENV        = var.env
    AWS_REGION      = var.aws_region
    KAMBRIQ_ENV     = var.env  # dev ou prod, pour détecter l'environnement SSM
    # Les secrets (DATABASE_URL, JWT_SECRET, etc.) sont lus depuis SSM au runtime
  }
}
```

### Chargement des Secrets au Runtime

L'API charge automatiquement les secrets depuis SSM au démarrage via `api/src/infrastructure/config/config-loader.ts` :

1. **Détection de l'environnement** :
   - Local : `NODE_ENV === 'development'` ou `AWS_EXECUTION_ENV` non défini → utilise `.env`
   - Lambda : lit `KAMBRIQ_ENV` (dev/prod) → lit depuis SSM

2. **Lecture depuis SSM** :
   - Path : `/kambriq/{KAMBRIQ_ENV}/api/{parameter_name}`
   - Paramètres lus : `DATABASE_URL`, `JWT_SECRET`, `FRONTEND_URL`, `SES_FROM_EMAIL`
   - Injection dans `process.env`

3. **Avantages** :
   - Secrets non exposés dans les variables d'environnement Lambda
   - Rotation des secrets possible sans redéployer le code
   - Séparation claire entre infrastructure (Terraform) et secrets (SSM)

## Frontend Build Configuration

### Next.js Environment Variables

Next.js requires environment variables to be prefixed with `NEXT_PUBLIC_` to be accessible in the browser.

### Build-Time Injection (GitHub Actions)

Les variables `NEXT_PUBLIC_*` sont fournies par les workflows GitHub Actions lors du build :

**Dans `deploy-app-dev.yml` et `deploy-app-prod.yml`** :
- Les variables `NEXT_PUBLIC_*` peuvent être définies via les secrets GitHub (si nécessaire)
- Généralement, ces valeurs sont non sensibles (URLs, domaines, etc.)
- Le build OpenNext est effectué avec ces variables

### OpenNext Build

For OpenNext deployment (S3 + Lambda SSR), use:

```bash
pnpm build:opennext
```

This generates the `.open-next/` directory with:
- Static assets for S3 (`.open-next/assets/`)
- Lambda functions for SSR (`.open-next/server/`)
- Image optimization Lambda@Edge (`.open-next/image-optimization/`)

### Runtime SSR Configuration (Optionnel)

Si des valeurs dynamiques sont nécessaires au runtime SSR, elles peuvent être lues depuis SSM via `web/src/lib/runtimeConfig.ts` :

- Cache singleton pour éviter les appels SSM multiples
- Import dynamique de `@aws-sdk/client-ssm` pour éviter le bundling côté client
- Path SSM : `/kambriq/{env}/web/...`

**Note:** Static export (`pnpm export`) is no longer used. The frontend now uses OpenNext for SSR capabilities.

## Best Practices

### 1. Never Expose Secrets in Terraform Outputs

- ❌ **DO NOT** output passwords or secrets
- ✅ **DO** mark sensitive outputs with `sensitive = true`
- ✅ **DO** store secrets in SSM Parameter Store / Secrets Manager

### 2. Use SSM Parameter Store for Secrets

- Store `DATABASE_URL` in SSM (SecureString) : `/kambriq/{env}/api/DATABASE_URL`
- Store `JWT_SECRET` in SSM (SecureString) : `/kambriq/{env}/api/JWT_SECRET`
- Store `FRONTEND_URL` in SSM (String) : `/kambriq/{env}/api/FRONTEND_URL`
- Store `SES_FROM_EMAIL` in SSM (String) : `/kambriq/{env}/api/SES_FROM_EMAIL`

### 3. Construct DATABASE_URL Manually

The `DATABASE_URL` should be constructed manually (ou via script) et stocké dans SSM, pas dans Terraform, pour éviter d'exposer le mot de passe dans le state Terraform.

### 4. Secrets Loaded at Runtime

Les secrets sont lus depuis SSM au runtime par l'application, pas injectés dans les variables d'environnement Lambda. Cela permet :
- Rotation des secrets sans redéployer le code
- Séparation claire entre infrastructure et secrets
- Pas d'exposition des secrets dans les variables d'environnement Lambda

### 5. Version Control for Environment Files

- ✅ **DO** commit `.env.example` files with placeholder values
- ❌ **DO NOT** commit `.env` or `.env.local` files with real values
- ✅ **DO** document the mapping in `ENVIRONMENT_VARIABLES.md`

### 6. IAM Permissions

**Pour les workflows Terraform** (`terraform-dev.yml`, `terraform-prod.yml`) :
- Permissions pour créer/modifier les ressources AWS (Lambda, API Gateway, RDS, S3, CloudFront, SSM structure, IAM, VPC, etc.)
- Pas besoin de permissions pour lire/écrire les secrets applicatifs dans SSM (gérés manuellement)

**Pour les workflows de déploiement applicatif** (`deploy-app-dev.yml`, `deploy-app-prod.yml`) :
- Permissions pour `lambda:UpdateFunctionCode` (mise à jour du code Lambda)
- Permissions pour `s3:PutObject`, `s3:DeleteObject` (sync assets)
- Permissions pour `cloudfront:CreateInvalidation` (invalidation cache)
- **Pas besoin** de permissions pour lire/écrire SSM (l'application lit depuis SSM au runtime avec son propre rôle IAM)

### 7. Environment-Specific Configuration

Use separate Terraform workspaces or directories for each environment:
- `envs/dev/` - Development environment
- `envs/prod/` - Production environment
- `envs/shared/` - Shared resources (VPC, Route53, SES domain)

## Troubleshooting

### Issue: `dev.kambriq.com` returns `{"Message": null}` instead of Next.js app

**Symptom:** After deployment, accessing `https://dev.kambriq.com/` (or `https://kambriq.com/` in prod) returns `{"Message": null}` instead of the Next.js application HTML.

**Root Causes (Multiple Issues Fixed):**

1. **OpenNext Streaming Mismatch:**
   - OpenNext was configured with `streaming: true` in `opennext.config.ts`, which generates a handler using `awslambda.streamifyResponse()`. However, the Lambda Function URL was using the default `BUFFERED` invoke mode (not `RESPONSE_STREAM`). This mismatch causes the handler to fail silently.

2. **React Development Files Missing:**
   - Lambda environment variable `NODE_ENV` was set to `var.env` (e.g., "dev"), causing React to look for `react.development.js` files. However, OpenNext bundles are built in production mode and only contain `react.production.js` files, leading to `Runtime.ImportModuleError: Cannot find module './cjs/react.development.js'`.

3. **CloudFront Host Header Issue:**
   - CloudFront was forwarding the `Host` header from the viewer request (`dev.kambriq.com`) to the Lambda Function URL origin. However, Lambda Function URLs expect their own hostname (`*.lambda-url.region.on.aws`), causing `403 AccessDeniedException` errors.

**Complete Solution (All fixes applied in `modules/frontend/main.tf`):**

1. **Disable streaming in OpenNext** (`web/opennext.config.ts`):
   ```typescript
   lambda: {
     streaming: false,  // Must match Function URL invoke_mode
   }
   ```

2. **Force NODE_ENV=production in Lambda** (`modules/frontend/main.tf`):
   ```hcl
   environment {
     variables = {
       # Force NODE_ENV=production for Lambda runtime
       # OpenNext bundles are built in production mode, so React expects production files
       NODE_ENV = "production"
       # ... other variables
     }
   }
   ```

3. **Create CloudFront Origin Request Policy** (excludes Host header):
   ```hcl
   resource "aws_cloudfront_origin_request_policy" "lambda_ssr" {
     name    = "${local.name_prefix}-lambda-ssr-origin-request"
     comment = "Origin request policy for Lambda Function URL SSR - excludes Host header"
     
     headers_config {
       header_behavior = "whitelist"
       headers {
         items = ["Accept", "Content-Type", "Origin", "Referer", "User-Agent"]
       }
     }
     # ... other config
   }
   ```

4. **Create CloudFront Cache Policy** (for disabled caching):
   ```hcl
   resource "aws_cloudfront_cache_policy" "lambda_ssr" {
     name        = "${local.name_prefix}-lambda-ssr-cache"
     comment     = "Cache policy for Lambda Function URL SSR - no caching"
     default_ttl = 0
     max_ttl     = 0
     min_ttl     = 0
     # ... config with all behaviors set to "none" for disabled caching
   }
   ```

5. **Apply policies to default cache behavior**:
   ```hcl
   default_cache_behavior {
     cache_policy_id          = aws_cloudfront_cache_policy.lambda_ssr.id
     origin_request_policy_id = aws_cloudfront_origin_request_policy.lambda_ssr.id
     # ... other config
   }
   ```

**Verification:**
- After fixes: `curl https://dev.kambriq.com/` should return HTML (200 OK)
- Check CloudWatch Logs for Lambda `kambriq-frontend-dev-ssr` to see handler execution
- No more `react.development.js` errors in logs
- No more `403 AccessDeniedException` from CloudFront

**Note:** These fixes are applied in the shared `modules/frontend/main.tf` module, so they automatically apply to both DEV and PROD environments. No separate configuration needed per environment.

## Troubleshooting (Legacy)

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
Navigateur → CloudFront → S3 (OpenNext assets)
           → CloudFront → Lambda SSR (OpenNext)
           → API Gateway → Lambda (NestJS)
```

**Note:** The frontend now uses OpenNext (SSR + Lambda) instead of static export. The `modules/frontend/` module handles S3, CloudFront, and Lambda SSR configuration.

### Required Changes

#### 1. Update Frontend Module (OpenNext)

**File** : `modules/frontend/main.tf`

The frontend module already handles:
- S3 bucket for OpenNext static assets
- CloudFront distribution with OAC (Origin Access Control)
- Lambda SSR function (placeholder, updated via CI/CD)
- Integration with API Gateway via environment variables

**Note:** The `modules/cloudfront/` and `modules/s3-static-site/` modules are now LEGACY and replaced by `modules/frontend/`.

#### 2. Legacy: Update CloudFront Module (if using legacy modules)

**File** : `modules/cloudfront/main.tf` ⚠️ LEGACY

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

#### 3. Update Environment Configurations

**Files** : `envs/dev/main.tf`, `envs/prod/main.tf`

**For OpenNext (current architecture):**

Pass the API Gateway endpoint to the frontend module:

```hcl
module "frontend" {
  source = "../../modules/frontend"
  
  env                = local.env
  api_gateway_url    = module.api_gateway.api_gateway_base_url
  # Les variables artifact_bucket_name et ssr_bundle_s3_key ne sont plus utilisées
  # Le code applicatif est déployé via deploy-app-dev.yml / deploy-app-prod.yml
  # ... other variables
}
```

**⚠️ Legacy: Les modules s3-static-site et cloudfront sont obsolètes. Utiliser le module frontend/ avec OpenNext.**

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

