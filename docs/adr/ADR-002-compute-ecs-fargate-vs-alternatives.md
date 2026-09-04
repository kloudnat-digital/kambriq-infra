# ADR-002: Compute — ECS Fargate over EKS / EC2 / Lambda

Date: 2026-04-17
Status: Accepted
Deciders: Kambriq Engineering Team

---

## Context and Problem Statement

The Kambriq API is a containerised NestJS application with long-lived connections (database, Redis, BullMQ workers). We need a managed compute layer that:
- Runs Docker containers without managing EC2 fleets
- Keeps costs low for a dev/prd two-environment setup
- Is operationally simple for a small team
- Supports rolling deployments and health-based traffic shifting

---

## Decision Drivers

- **Cost**: Minimise idle compute cost; dev runs 1 task only
- **Operational simplicity**: No cluster nodes, no patching
- **Container-native**: App is already Dockerised
- **Managed integrations**: Native ALB, CloudWatch, ECR, SSM, IAM task roles

---

## Considered Options

1. **ECS Fargate** ← chosen
2. EKS (Kubernetes)
3. EC2 Auto Scaling Group
4. AWS Lambda (serverless)
5. AWS App Runner

---

## Decision Outcome

**Chosen: ECS Fargate**

ECS Fargate provides serverless containers with per-second billing, native integration with ALB target groups, and first-class support for IAM task roles (used for SSM parameter reads, S3 access).

---

## Pros and Cons of the Options

### Option 1: ECS Fargate ✅

**Good:**
- No EC2 nodes to patch or scale
- Per-second billing — cost-effective for low-traffic dev
- Native ALB integration (IP-mode target groups)
- Task-level IAM roles → fine-grained permissions
- Init containers for migrations (`dependsOn: START`)
- CloudWatch Container Insights available (deliberately **disabled** on dev: $14.55/month in August, $0.00 in September)
- Rolling deployments without downtime

**Bad:**
- Cold start latency (~10–30s) if task stops
- No persistent local storage (use S3/EFS instead)
- Maximum 4 vCPU / 30 GB RAM per task (sufficient for current scale)

### Option 2: EKS

**Good:** Full Kubernetes ecosystem, Horizontal Pod Autoscaler, better for multi-team orgs

**Bad:**
- $0.10/hour control plane fee regardless of load (~$73/month added cost)
- High operational complexity for a small team
- Overkill for two services and two environments

### Option 3: EC2 Auto Scaling Group

**Good:** Full control, cheapest at sustained high CPU

**Bad:**
- Must manage AMIs, patching, instance refresh
- Over-provisioning required for headroom
- No per-second billing

### Option 4: AWS Lambda

**Good:** True scale-to-zero, cheapest for intermittent workloads

**Bad:**
- NestJS bootstrap time (~2–5s) causes cold starts on HTTP requests
- BullMQ workers require long-running processes — incompatible
- Prisma connection pooling doesn't fit Lambda lifecycle

### Option 5: App Runner

**Good:** Simplest deployment, auto-scaling

**Bad:**
- No VPC-native deployment for private RDS access (requires VPC connector, adds complexity)
- Less control over task IAM roles
- Higher per-vCPU cost than Fargate at sustained load

---

## Cost Impact (dev, monthly estimate)

| Option | Monthly Cost |
|--------|-------------|
| ECS Fargate (1×512CPU/1GB, ~8h/day) | ~$8/month |
| ECS Fargate (1×512CPU/1GB, 24/7) | ~$22/month |
| EKS + Fargate | $73 + compute |
| EC2 t3.small | ~$15/month |
| Lambda | ~$0–5/month (depends on traffic) |

Fargate provides the best balance of cost and operational simplicity for the current scale.

---

## Consequences

- ECS task definitions are versioned (each deploy registers a new revision)
- Migrations run as one-off Fargate tasks (not as init containers in the task definition) via CI/CD
- Task CPU/memory can be adjusted in `terraform.tfvars` without code changes
- Graviton2 (ARM) should be evaluated for 20% cost savings (see ADR-003)
