# ADR-006: Testing Strategy — Terraform Module Tests, Smoke Tests, and E2E

Date: 2026-04-17
Status: Accepted
Deciders: Kambriq Engineering Team

---

## Context and Problem Statement

Prior to this decision the repository had no automated testing beyond Terraform's built-in `validate` and `plan` commands. This left several classes of defect undetected until a real deployment:

- **Module regressions**: changing a variable default in `modules/alb/` or `modules/rds-postgres/` could silently remove a security property (e.g. `storage_encrypted`, `publicly_accessible`) or break a convention (e.g. default port) with no fast feedback.
- **Post-deploy brokenness**: `terraform apply` succeeding is not the same as the application being healthy. ECS tasks could fail to start, the ALB could be misconfigured, or a health endpoint could start returning errors — none of which are caught by plan/apply output alone.
- **Application-level regressions**: infrastructure changes can break the web application in ways only visible to a browser (redirect loops, missing env vars, auth misconfiguration).

The three gaps map neatly to three test layers, each with different scope, speed, and cost.

---

## Decision

Adopt a three-layer testing strategy:

| Layer | Scope | Tool | Cost |
|-------|-------|------|------|
| 1 — Terraform module unit tests | Module logic and defaults | `terraform test` + `mock_provider` | Free (no AWS calls) |
| 2 — Infrastructure smoke tests | Deployed environment health | Bash script + curl + AWS CLI | Minimal (read-only AWS calls) |
| 3 — Application E2E tests | Full browser flows | Playwright (in `kambriq-webapp`) | Low (runs against existing deploy) |

---

## Layer 1 — Terraform Module Unit Tests (`terraform test`)

**What**: validates that module variables have correct defaults and that resources are configured with the expected security properties, without creating any real AWS resources.

**How**: Terraform 1.7+ `mock_provider "aws" {}` allows `terraform test` to plan against a fake provider. Tests are written in `.tftest.hcl` files inside a `tests/` subdirectory of each module.

**Where**:
- `modules/alb/tests/defaults.tftest.hcl` — asserts default ports, access logging disabled, deletion protection disabled.
- `modules/rds-postgres/tests/defaults.tftest.hcl` — asserts `storage_encrypted = true`, `publicly_accessible = false`, default backup retention, `multi_az` off by default, `skip_final_snapshot` on by default.

**When**: CI runs these on every pull request that touches `modules/` or `envs/`, and on `workflow_dispatch`. The `module-tests` job in `terraform-plan.yml` runs independently of the `plan` job (no `needs` dependency) so module test failures are surfaced immediately without waiting for credential-dependent plan steps.

**How to run locally**:

```bash
# ALB module
terraform -chdir=modules/alb init -backend=false
terraform -chdir=modules/alb test

# RDS module
terraform -chdir=modules/rds-postgres init -backend=false
terraform -chdir=modules/rds-postgres test
```

---

## Layer 2 — Infrastructure Smoke Tests

**What**: validates that a deployed environment is actually serving traffic and that ECS services are healthy. Checks HTTP response codes, JSON response bodies, and ECS running task counts.

**Where**: `scripts/smoke-test.sh`

**Checks performed**:

| Check | Method |
|-------|--------|
| `GET /api/v1/health/ready` returns HTTP 200 | curl with retry |
| API health body contains `{"status":"ok"}` | curl + python3 JSON parse |
| `GET /health` (web) returns HTTP 200 | curl with retry |
| Web health body contains `{"status":"ok"}` | curl + python3 JSON parse |
| Root page `/` returns HTTP 200 | curl |
| Login page `/login` returns HTTP 200 | curl |
| ECS API service: `status=ACTIVE`, `running == desired >= 1` | AWS CLI `describe-services` |
| ECS Web service: `status=ACTIVE`, `running == desired >= 1` | AWS CLI `describe-services` |

HTTP checks retry up to 5 times with a 5-second delay to tolerate brief startup delays after a fresh deploy. All failures are accumulated; the script exits 1 only at the end, so every check is always reported.

**When**: `smoke-test.yml` triggers automatically via `workflow_run` when `terraform-apply.yml` completes with `conclusion == 'success'`. It can also be triggered manually via `workflow_dispatch` for either `dev` or `prd`.

**How to run locally**:

```bash
chmod +x scripts/smoke-test.sh

# Against dev (default)
./scripts/smoke-test.sh dev

# Against prd
./scripts/smoke-test.sh prd

# Override URLs for local/staging testing
WEB_URL=https://staging.example.com API_URL=https://staging.example.com ./scripts/smoke-test.sh dev
```

---

## Layer 3 — Application E2E Tests (Playwright, `kambriq-webapp`)

**What**: full browser tests that exercise the deployed web application from a user's perspective. These tests live in the `kambriq-webapp` repository and run against the deployed URL, not against localhost.

**Tests include**:
- Health endpoint assertions (`/api/v1/health/ready`, `/health`)
- Authentication flow (login page renders, form submits, redirects to dashboard)
- Protected route redirects (unauthenticated requests to `/dashboard` redirect to `/login`)
- Public page accessibility (root `/`, `/login`, marketing pages)

**When**:
- After `deploy-dev` completes in `kambriq-webapp`'s `ci.yml` (the `e2e` job depends on `deploy-dev`)
- After `deploy-prd` completes (same pattern)

---

## Automated Pipeline Flow

```
PR touches modules/ or envs/
  └── terraform-plan.yml
        ├── detect-envs + plan  (existing jobs, require AWS credentials)
        └── module-tests        (new, no AWS credentials needed)
              ├── terraform test modules/alb       (mock_provider)
              └── terraform test modules/rds-postgres (mock_provider)

terraform-apply.yml completes successfully
  └── smoke-test.yml  (workflow_run trigger)
        ├── GET /api/v1/health/ready  → HTTP 200 + {"status":"ok"}
        ├── GET /health               → HTTP 200 + {"status":"ok"}
        ├── GET /                     → HTTP 200
        ├── GET /login                → HTTP 200
        ├── ECS API service           → ACTIVE, running == desired
        └── ECS Web service           → ACTIVE, running == desired

(in kambriq-webapp repo)
develop push
  └── ci.yml
        quality → build → deploy-dev
          └── e2e  (Playwright against dev.kambriq.com)
```

---

## Consequences

**Positive**:
- Module regressions in security-sensitive defaults (encryption, public access) are caught at PR time, before any AWS credentials are involved.
- Post-deploy health is validated automatically — a broken deploy is caught without waiting for user reports.
- The three layers are independently triggerable, making debugging straightforward: a failing module test points to Terraform logic, a failing smoke test points to the deployed infrastructure, a failing E2E test points to the application.
- `mock_provider` tests run entirely without network access and complete in seconds.

**Negative / Trade-offs**:
- `mock_provider` tests cannot validate provider-level behaviours (e.g. AWS service limits, IAM policy evaluation). They test the module's Terraform logic, not AWS's enforcement of that logic.
- The smoke test requires the environment to already be deployed. It cannot detect issues pre-apply.
- E2E Playwright tests add CI time (~2–5 min) and require a stable deployed environment. Flaky network conditions can cause spurious failures; the smoke test's retry logic mitigates this for the simpler HTTP checks.
- `workflow_run` triggers for `smoke-test.yml` always run in the context of the default branch, not the merged branch. This is a GitHub Actions constraint; the `workflow_dispatch` path avoids it for manual re-runs.
