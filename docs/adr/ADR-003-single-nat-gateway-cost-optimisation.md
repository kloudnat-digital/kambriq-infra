# ADR-003: Single NAT Gateway for Cost Optimisation

Date: 2026-04-17
Status: Accepted
Deciders: Kambriq Engineering Team

---

## Context and Problem Statement

ECS tasks, RDS, and Redis run in private subnets and need outbound internet access (ECR image pulls, SSM parameter reads, SES API calls). AWS charges $0.045/hour per NAT Gateway plus $0.045/GB data processed. With two AZs, two NAT Gateways would double that base cost.

---

## Decision Drivers

- Cost-first: minimise monthly spend, especially for dev
- The system currently has no requirement for AZ-level NAT redundancy
- All ECS tasks can tolerate the single-NAT SPOF in dev

---

## Considered Options

1. **Single NAT Gateway (one AZ)** ← chosen
2. One NAT Gateway per AZ (HA)
3. NAT Instance (EC2-based)

---

## Decision Outcome

**Chosen: Single NAT Gateway**

One NAT Gateway in a single public subnet. All private subnets route outbound traffic through it via the route table.

```hcl
# envs/shared/terraform.tfvars
nat_per_az = false
```

---

## Pros and Cons

### Option 1: Single NAT Gateway ✅

**Good:**
- Saves ~$33/month (one vs two NAT Gateways at $0.045/hr)
- Sufficient for dev; acceptable in prd for current traffic volume

**Bad:**
- If the NAT Gateway's AZ has an outage, all private subnet internet access fails
- Cross-AZ data charges if ECS tasks are in a different AZ than NAT (~$0.01/GB)

### Option 2: One NAT per AZ (HA)

**Good:** True AZ-level redundancy, eliminates cross-AZ NAT traffic charges

**Bad:**
- ~$33/month additional cost per environment
- Overkill given current SLA requirements

### Option 3: NAT Instance (EC2)

**Good:** Cheapest option — a t4g.nano costs ~$3/month

**Bad:**
- Must manage patching, HA, monitoring
- Throughput limited by instance bandwidth
- Deprecated by AWS guidance

---

## Cost Comparison (monthly, single environment)

| Option | NAT Cost |
|--------|---------|
| Single NAT | ~$33 |
| Dual NAT (HA) | ~$66 |
| NAT Instance t4g.nano | ~$3 |

---

## Consequences

- **Accepted risk**: NAT AZ failure affects all private subnet outbound connectivity
- **Mitigation**: ECS service places tasks using `SPREAD` strategy across AZs; if NAT fails, existing connections continue until task restart
- **Review trigger**: Enable `nat_per_az = true` when SLA > 99.9% is required or when prd traffic exceeds ~100 GB/month cross-AZ (at which point HA NAT data savings offset the extra gateway cost)
