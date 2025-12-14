# ECR Repository Module

This module creates an ECR repository for Lambda container images.

## Usage

```hcl
module "ecr_api" {
  source = "../../modules/ecr-repository"

  repository_name = "kambriq-api-dev"
  env             = "dev"
}
```

## Important: Placeholder Image Required

**⚠️ Before creating a Lambda function with `package_type = "Image"`, you must push a placeholder image to the ECR repository.**

The Lambda function creation will fail if the image doesn't exist. You can create a minimal placeholder image using:

```bash
# Get ECR login token
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com

# Pull AWS Lambda base image
docker pull public.ecr.aws/lambda/nodejs:20

# Tag it for your ECR repository
docker tag public.ecr.aws/lambda/nodejs:20 <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev:latest

# Push to ECR
docker push <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev:latest
```

Or use the provided script:

```bash
./scripts/create-ecr-placeholder-image.sh kambriq-api-dev eu-central-1
```

## Outputs

- `repository_url`: Full ECR repository URL
- `repository_arn`: ECR repository ARN
- `repository_name`: ECR repository name
