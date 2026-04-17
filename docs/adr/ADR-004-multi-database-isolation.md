# ADR-004: Multiple Isolated PostgreSQL Databases on a Single RDS Instance

Date: 2026-04-17
Status: Accepted
Deciders: Kambriq Engineering Team

---

## Context and Problem Statement

The Kambriq platform has four business domains (Core, KBS, KAMNET, Lands) each with distinct data models. We need to decide how to isolate their data: separate RDS instances, separate databases on a shared instance, or PostgreSQL schemas within one database.

---

## Decision Drivers

- **Cost**: RDS instances are the largest cost item; minimise instance count
- **Domain isolation**: Schema changes in one domain must not break another
- **Independent migrations**: Each domain runs its own Prisma migrations independently
- **Connection management**: Each ECS task must connect to the right database
- **Operational simplicity**: One endpoint, one backup schedule, one parameter group

---

## Considered Options

1. **Multiple databases on one RDS instance** ← chosen
2. One RDS instance per domain (4 instances)
3. Multiple PostgreSQL schemas on one database
4. Separate RDS clusters (Aurora Serverless)

---

## Decision Outcome

**Chosen: Multiple databases on one RDS instance**

Four databases (`kambriq_core`, `kambriq_kbs`, `kambriq_kamnet`, `kambriq_lands`) run on a single `kambriq-postgres-dev` RDS instance. Each has a `DATABASE_URL_*` connection string stored in SSM Parameter Store and injected independently into the API container.

```
postgres://kambriq_admin:***@kambriq-postgres-dev.*.rds.amazonaws.com:5432/kambriq_core
postgres://kambriq_admin:***@kambriq-postgres-dev.*.rds.amazonaws.com:5432/kambriq_kbs
postgres://kambriq_admin:***@kambriq-postgres-dev.*.rds.amazonaws.com:5432/kambriq_kamnet
postgres://kambriq_admin:***@kambriq-postgres-dev.*.rds.amazonaws.com:5432/kambriq_lands
```

Each domain has its own Prisma schema with isolated migrations:
```
prisma/core/schema.prisma    → client → libs/common/src/prisma/core-client/
prisma/kbs/schema.prisma     → client → libs/common/src/prisma/kbs-client/
prisma/kamnet/schema.prisma  → client → libs/common/src/prisma/kamnet-client/
prisma/lands/schema.prisma   → client → libs/common/src/prisma/lands-client/
```

---

## Pros and Cons of the Options

### Option 1: Multiple databases on one RDS instance ✅

**Good:**
- Single RDS cost (~$15/month for db.t4g.micro in dev)
- One backup job covers all domains
- One endpoint to manage
- Full data isolation at the DB level (no cross-domain JOIN possible)
- Independent Prisma migrations per domain

**Bad:**
- Shared CPU/RAM/IO — one runaway query can affect all domains
- Cannot independently scale storage per domain
- Shared master password (mitigated by per-domain connection strings in SSM)

### Option 2: One RDS instance per domain

**Good:** Full resource isolation, independent scaling

**Bad:**
- 4× the RDS cost: ~$60+/month in dev for 4×db.t4g.micro
- 4× backup/monitoring overhead
- 4× connection endpoints to manage

### Option 3: Multiple schemas on one database

**Good:** Single connection string, lightweight

**Bad:**
- Prisma does not support multi-schema migrations on a single connection natively
- Cross-schema foreign keys create tight coupling
- No clean domain boundary at the DB level

### Option 4: Aurora Serverless

**Good:** Scale to zero, pay per ACU

**Bad:**
- Aurora minimum cost higher than RDS t4g.micro for low-traffic dev
- Cold start latency on first connection
- More complex setup

---

## Cost Impact

| Configuration | Monthly Cost (dev) |
|--------------|-------------------|
| 1 RDS db.t4g.micro (chosen) | ~$15 |
| 4 RDS db.t4g.micro | ~$60 |
| Aurora Serverless v2 (min 0.5 ACU) | ~$45 |

---

## Consequences

- **Migration isolation**: `pnpm db:migrate:deploy:core` is independent of `:kbs`, etc. A migration failure in KBS does not block Core
- **Connection pool**: The NestJS API opens 4 Prisma clients, each with its own connection pool. Monitor total connections under load
- **Future domains** (Verify, Valuation): Add `DATABASE_URL_VERIFY` etc. to SSM and create new `prisma/{domain}/schema.prisma` — no infra change required beyond the `db_extra` Terraform variable
- **Review trigger**: If any single domain exceeds 70% of RDS CPU/memory, evaluate moving it to a dedicated instance
