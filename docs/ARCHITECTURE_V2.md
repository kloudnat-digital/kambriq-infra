# Architecture KAMBRIQ v2.0

## Vue d'Ensemble

KAMBRIQ v2.0 utilise une architecture **ECS Fargate + ALB + CloudFront** pour remplacer l'architecture serverless V1 (Lambda + OpenNext).

## Composants

### 1. CloudFront Distribution

**Rôle:** CDN et point d'entrée principal

**Configuration:**
- Origin: ALB (HTTPS)
- Domain: `dev.kambriq.com` (via Route53)
- Certificate: ACM (us-east-1)

**Cache Behaviors:**
- `/api/*` → ALB (no cache, forward all)
- `/*` → ALB (cache static assets, no cache SSR)

### 2. Application Load Balancer (ALB)

**Rôle:** Routage et load balancing

**Configuration:**
- Type: Internet-facing
- Subnets: Public subnets (2 AZ)
- Certificate: ACM (eu-central-1)

**Listeners:**
- HTTPS (443): Routing rules
- HTTP (80): Redirect to HTTPS

**Target Groups:**
- API Target Group: Port 8000 (FastAPI)
- Web Target Group: Port 3000 (Next.js)

**Routing Rules:**
- `/api/*` → API Target Group
- `/*` → Web Target Group

### 3. ECS Cluster

**Rôle:** Orchestration des containers

**Configuration:**
- Launch Type: Fargate
- Container Insights: Enabled
- Logs: CloudWatch Logs

**Services:**
- `kambriq-dev-api`: FastAPI service
- `kambriq-dev-web`: Next.js service

### 4. ECS Services

#### API Service (FastAPI)

- **Image:** ECR `kambriq-api-dev`
- **Port:** 8000
- **CPU:** 256 (0.25 vCPU)
- **Memory:** 512 MB
- **Subnets:** Private subnets
- **Security Group:** ECS security group
- **Health Check:** `/api/health`

#### Web Service (Next.js)

- **Image:** ECR `kambriq-web-dev`
- **Port:** 3000
- **CPU:** 256 (0.25 vCPU)
- **Memory:** 512 MB
- **Subnets:** Private subnets
- **Security Group:** ECS security group
- **Health Check:** `/health`

### 5. RDS PostgreSQL

**Rôle:** Base de données principale

**Configuration:**
- Engine: PostgreSQL 15
- Instance: db.t4g.micro
- Storage: 20 GB gp3
- Subnets: Private subnets
- Security Group: RDS security group (ECS → RDS only)

### 6. Security Groups

#### ALB Security Group
- Ingress: 80, 443 from 0.0.0.0/0
- Egress: All to ECS security group

#### ECS Security Group
- Ingress: All from ALB security group
- Egress: All (for internet access via NAT Gateway)
- Egress: 5432 to RDS security group

#### RDS Security Group
- Ingress: 5432 from ECS security group
- Egress: None

### 7. IAM Roles

#### ECS Task Execution Role
- ECR pull permissions
- CloudWatch Logs write permissions

#### ECS Task Role (API)
- SSM Parameter Store read (`/kambriq/dev/api/*`, `/kambriq/dev/db/*`)
- RDS describe permissions

#### ECS Task Role (Web)
- SSM Parameter Store read (`/kambriq/dev/web/*`)

## Flux de Données

### Requête Utilisateur

1. **DNS:** `dev.kambriq.com` → CloudFront Distribution
2. **CloudFront:** 
   - `/api/*` → ALB (no cache)
   - `/*` → ALB (cache static)
3. **ALB:**
   - `/api/*` → API Target Group → ECS API Service
   - `/*` → Web Target Group → ECS Web Service
4. **ECS:**
   - API Service → FastAPI container
   - Web Service → Next.js container
5. **Database:**
   - FastAPI → RDS PostgreSQL (via private subnet)

### Authentification

1. **Login:** `POST /api/auth/login`
   - FastAPI vérifie credentials
   - Génère JWT access token (15 min)
   - Génère refresh token (7 jours)
   - Set refresh token cookie (HttpOnly, Secure, SameSite=Lax)
   - Retourne access token dans response

2. **API Calls:**
   - Frontend envoie access token dans header `Authorization: Bearer <token>`
   - FastAPI vérifie token
   - Si expiré, frontend appelle `/api/auth/refresh` (utilise cookie automatiquement)

3. **Refresh:**
   - Frontend appelle `/api/auth/refresh` (cookie automatique)
   - FastAPI vérifie refresh token
   - Génère nouveau access token
   - Optionnellement rotate refresh token

## Scalabilité

### Horizontal Scaling

- **ECS Services:** Auto-scaling configurable (CPU/Memory based)
- **ALB:** Gère automatiquement le load balancing
- **CloudFront:** CDN global

### Vertical Scaling

- **ECS Tasks:** Augmenter CPU/Memory si nécessaire
- **RDS:** Upgrade instance class si nécessaire

## Haute Disponibilité

- **Multi-AZ:** ECS tasks dans 2 AZ
- **ALB:** Multi-AZ par défaut
- **RDS:** Peut être configuré en Multi-AZ (coût supplémentaire)

## Monitoring

- **CloudWatch Logs:** Logs ECS tasks
- **CloudWatch Metrics:** CPU, Memory, Request count
- **ALB Metrics:** Request count, 5xx errors, latency
- **RDS Metrics:** CPU, Memory, Connections

## Coûts Estimés (1k-5k users, 10 req/s peak)

- **ECS Fargate (2 tasks):** ~$30-40/mois
- **ALB:** ~$16/mois
- **CloudFront:** ~$5-10/mois
- **RDS (t4g.micro):** ~$15/mois
- **Total:** ~$66-81/mois

## Comparaison V1 vs V2

| Aspect | V1 (Lambda) | V2 (ECS) |
|--------|-------------|----------|
| **Coût** | ~$20-35/mois | ~$66-81/mois |
| **Performance** | Cold start | Pas de cold start |
| **Scalabilité** | Auto (Lambda) | Auto (ECS) |
| **Complexité** | Faible | Moyenne |
| **Maintenance** | Faible | Moyenne |
| **Flexibilité** | Limitée | Élevée |

