# ADR-001: Kambriq Platform — Global Architecture

Date: 2026-04-17
Status: Accepted
Deciders: Kambriq Engineering Team
Consulted: Infrastructure Team

---

## Context and Problem Statement

The Kambriq platform serves multiple business domains (authentication, training, agent networks, land management) and must be deployable to AWS in a cost-effective, maintainable, and scalable way. We need a clear architecture record describing how the full system fits together — from DNS to application code — so that any engineer can reason about deployments, failures, and changes.

---

## Architecture Overview

### Global Request Flow

```
                           Internet
                              │
                    ┌─────────▼──────────┐
                    │   Route53 DNS       │
                    │  dev.kambriq.com   │
                    │  kambriq.com (prd) │
                    └─────────┬──────────┘
                              │ A record → ALB
                    ┌─────────▼──────────┐
                    │  ALB (HTTPS :443)   │
                    │  HTTP→HTTPS :80     │
                    │  ACM certificate    │
                    └──────┬──────┬───────┘
                           │      │
              /api/*        │      │  /*
         ┌────▼────┐   ┌───▼──────┐
         │ECS API  │   │ECS Web   │
         │NestJS   │   │Next.js   │
         │:3000    │   │:3001     │
         └────┬────┘   └──────────┘
              │
     ┌────────┼────────────┐
     ▼        ▼            ▼
 ┌───────┐ ┌──────┐  ┌──────────┐
 │  RDS  │ │Redis │  │SSM Params│
 │PG 15  │ │7.1   │  │Secrets   │
 │4 DBs  │ │Cache │  │          │
 └───────┘ └──────┘  └──────────┘
              │
     ┌────────┼─────────┐
     ▼        ▼         ▼
 ┌───────┐ ┌─────┐ ┌──────┐
 │  S3   │ │ SES │ │ ECR  │
 │Media  │ │Email│ │Images│
 └───────┘ └─────┘ └──────┘
```

### Infrastructure Layer (kambriq-infra)

```
kambriq-infra/
├── envs/shared/     → VPC, NAT Gateway, Route53 zone, ACM cert, SES, GitHub OIDC, S3 state
├── envs/dev/        → All app resources for development environment
├── envs/prd/        → All app resources for production environment
└── modules/         → Reusable Terraform modules
```

**Apply order**: `shared` → `dev` | `prd`

The `dev` and `prd` environments read shared outputs via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config  = { bucket = "kloudnat-infra-shared-store", key = "kambriq/envs/shared/terraform.tfstate" }
}
```

### Application Layer (kambriq-webapp)

```
kambriq-webapp/  (pnpm + Nx monorepo)
├── apps/api/     → NestJS v11 — 4 domain modules (core, kbs, kamnet, lands)
├── apps/web/     → Next.js v16 — App Router, SSR, i18n (fr/en)
├── libs/common/  → Shared NestJS guards, filters, decorators, email, queue helpers
└── prisma/       → 4 isolated schemas, one per domain database
```

### Network Layout

```
VPC: 10.0.0.0/16 (eu-central-1)
│
├── Public Subnets (eu-central-1a, eu-central-1b)
│   ├── ALB                → internet-facing load balancer
│   ├── NAT Gateway        → single NAT (cost optimisation)
│   └── Bastion EC2        → t3.micro, SSH + SSM access
│
└── Private Subnets (eu-central-1a, eu-central-1b)
    ├── ECS Fargate Tasks  → API + Web containers
    ├── RDS PostgreSQL 15  → db.t4g.micro (dev) / db.t4g.small (prd)
    └── ElastiCache Redis  → cache.t4g.micro (dev) / cache.t4g.small (prd)
```

### Security Groups

| Resource | Inbound | From |
|----------|---------|------|
| ALB | 80, 443 | 0.0.0.0/0 |
| ECS API | 3000 | ALB SG |
| ECS Web | 3001 | ALB SG |
| RDS | 5432 | ECS SG + Bastion SG |
| Redis | 6379 | ECS SG |
| Bastion | 22 | `bastion_allowed_ssh_cidrs` |

### CI/CD Flow

```
Developer pushes to develop
       │
       ▼
GitHub Actions (deploy-dev.yml)
       │
  1. pnpm install
  2. lint + typecheck + test
  3. docker build → push ECR
  4. register new ECS task definition
  5. ECS one-off task: prisma migrate deploy
  6. ECS one-off task: db:seed (dev only)
  7. ECS update-service (rolling deploy)
  8. wait services-stable
  9. smoke test: GET /api/v1/health/ready
       │
       ▼
     Live at dev.kambriq.com
```

### Secrets Management

All sensitive values are stored in AWS SSM Parameter Store as `SecureString`:

```
/kambriq/{env}/api/JWT_SECRET
/kambriq/{env}/api/DATABASE_URL_CORE
/kambriq/{env}/api/DATABASE_URL_KBS
/kambriq/{env}/api/DATABASE_URL_KAMNET
/kambriq/{env}/api/DATABASE_URL_LANDS
/kambriq/{env}/db/DB_PASSWORD
/kambriq/{env}/web/NEXTAUTH_SECRET
```

ECS task definitions reference these via `valueFrom` in container definitions. No secrets are stored in environment variables directly or in git.

---

## Decision Outcome

This architecture provides:
- **Cost efficiency**: Single NAT, Graviton instances, minimal redundancy in dev
- **Security**: Private subnets for compute/data, HTTPS only, SSM secrets
- **Separation of concerns**: Infra repo vs app repo, per-domain databases
- **Reproducibility**: Terraform IaC with remote state, GitHub OIDC auth

---

## Environment Comparison

| Aspect | Dev | Prd |
|--------|-----|-----|
| API tasks | 1 | 2 |
| Web tasks | 1 | 2 |
| RDS class | db.t4g.micro | db.t4g.small |
| RDS Multi-AZ | No | Yes |
| Redis class | cache.t4g.micro | cache.t4g.small |
| RDS backups | 0 days | 30 days |
| Redis TLS | No | Yes |
| Redis auth token | No | Yes (set before apply) |
| Final snapshot | No | Yes |
| ALB access logs | No | Opt-in (set `alb_access_logs_bucket`) |

---

## Consequences

**Good:**
- Infrastructure changes are reviewed via `terraform-plan.yml` PR check before apply
- Dev environment costs are minimised (~$60–80/month estimated)
- Application code is decoupled from infra — can deploy each independently

**Bad / Known Gaps:**
- No CloudFront CDN in front of the ALB today (module exists, not wired)
- No WAF rules on the ALB
- `prd` Terraform stack not yet applied — production not yet live (see [ADR-005](./ADR-005-production-automation-prerequisites.md) for full bootstrap procedure)
- ALB access logs disabled until an S3 bucket is created and `alb_access_logs_bucket` is set in `envs/prd/terraform.tfvars`
