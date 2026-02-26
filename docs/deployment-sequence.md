# Deployment Sequence (Infra → API → Web)

This document describes the end-to-end deployment sequence across infrastructure,
API, and (later) Web. It is designed for both dev and prd flows.

## 1) Infrastructure (shared → env)

### Prerequisites
- AWS credentials with permissions to apply Terraform.
- GitHub Environments exist for `kambriq-api` (`dev`, `prd`).
- ACM certificate ARN for each environment (ALB HTTPS listener).

### Apply shared stack
```
terraform -chdir=envs/shared init -reconfigure
terraform -chdir=envs/shared apply
```

### Apply env stack (dev or prd)
Use secure DB password input (do not commit it to git):
```
export TF_VAR_db_password="$(aws ssm get-parameter --with-decryption --name /kambriq/dev/db/DB_PASSWORD --query Parameter.Value --output text)"
```

Then apply:
```
terraform -chdir=envs/dev init -reconfigure
terraform -chdir=envs/dev apply
```

### Push outputs to GitHub Environment
```
./scripts/set-github-vars.sh dev kloudnat-digital/kambriq-api
```

This sets:
- `AWS_REGION`, `ECR_REPO`, `ECS_CLUSTER`, `ECS_SERVICE`
- `ECS_TASK_DEFINITION`, `ECS_SUBNETS`, `ECS_SECURITY_GROUPS`
- `SMOKE_TEST_URL`, `AWS_ROLE_ARN`

## 2) API Deployment

### Dev (CI/CD)
- Trigger: push to `develop`.
- Steps: quality checks → build/push image (`vX.Y.Z` + `latest`) → register new
  task definition → run migrations (ECS one-off) → update ECS service → smoke test.
- Smoke test tries the vanity domain first and falls back to ALB DNS.

### Dev (local script)
```
./scripts/deploy-dev.sh
```

### Prd (CI/CD)
- Trigger: push `vX.Y.Z` git tag.
- Gate: tag must match `package.json` version.
- Same steps as dev.
- Only run after dev has been fully validated.

## 3) Web Deployment (later)

### Infra prerequisites
- Enable web service in env (`enable_web_service = true`).
- Ensure ECR repo exists for web and ALB target group is configured.
- Push outputs to GitHub env vars for `kambriq-web`.

### Web (CI/CD)
- Build/push image (`vX.Y.Z` + `latest`).
- Register new task definition and update ECS service.
- Smoke test (domain and ALB fallback).

## 4) Operations & Validation

### Verify DB via bastion (SSM)
Use the SSM port-forward instructions in `README.md` to access the DB and
verify seed data.

### Common troubleshooting
- If vanity domain fails, use ALB DNS output for health checks.
- If migrations fail, re-run the ECS one-off migration task.
