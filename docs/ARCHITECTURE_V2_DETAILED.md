# Architecture KAMBRIQ v2.0 - Documentation Détaillée

## Vue d'Ensemble

```
Internet
  ↓
CloudFront Distribution (dev.kambriq.com)
  ↓
Application Load Balancer (ALB)
  ├─ /api/* → API Target Group → ECS Service API (FastAPI :8000)
  └─ /* → Web Target Group → ECS Service Web (Next.js :3000)
       ↓
    RDS PostgreSQL (Private Subnet)
```

---

## 1. CloudFront Distribution

### Configuration

**Domain:** `dev.kambriq.com`  
**Certificate ARN:** `arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f`  
**Region:** `us-east-1` (requis pour CloudFront)  
**Type:** Web Distribution  
**IPv6:** Enabled

### Origin

**Type:** Custom Origin (ALB)  
**Domain:** `kambriq-dev-alb-XXXXXXXX.eu-central-1.elb.amazonaws.com`  
**Protocol:** HTTPS only  
**Port:** 443  
**Origin Protocol Policy:** HTTPS only  
**SSL Protocols:** TLSv1.2

**Custom Headers:**
- `X-Forwarded-Host`: `dev.kambriq.com`

### Cache Behaviors

#### 1. `/api/*` - No Cache (API Routes)

```yaml
Path Pattern: /api/*
Target Origin: ALB
Allowed Methods: DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT
Cached Methods: GET, HEAD
Forward Headers: All (*)
Forward Cookies: All
Forward Query Strings: Yes
Min TTL: 0
Default TTL: 0
Max TTL: 0
Compress: Yes
Viewer Protocol Policy: Redirect-to-HTTPS
```

**Raison:** Les routes API doivent toujours atteindre le backend pour traitement dynamique et authentification.

#### 2. `/*` - Default (Web Routes)

```yaml
Path Pattern: /* (default)
Target Origin: ALB
Allowed Methods: DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT
Cached Methods: GET, HEAD
Forward Headers: Host, Accept, Accept-Language, Accept-Encoding, Authorization, Cookie
Forward Cookies: All
Forward Query Strings: Yes
Min TTL: 0
Default TTL: 3600 (1 hour) - Static assets
Max TTL: 86400 (24 hours)
Compress: Yes
Viewer Protocol Policy: Redirect-to-HTTPS
```

**Raison:** Cache les assets statiques (.js, .css, images) mais pas le contenu SSR dynamique.

### Viewer Certificate

- **Type:** ACM Certificate
- **ARN:** `arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f`
- **SSL Support Method:** SNI-only
- **Minimum Protocol Version:** TLSv1.2_2021

### Geo Restrictions

- **Type:** None (accessible worldwide)

### Route53 DNS Record

```yaml
Type: A (Alias)
Name: dev.kambriq.com
Alias Target: CloudFront Distribution
Alias Hosted Zone ID: Z2FDTNDATAQYW2 (CloudFront)
```

---

## 2. Application Load Balancer (ALB)

### Configuration

**Name:** `kambriq-dev-alb`  
**Type:** Application Load Balancer (Layer 7)  
**Scheme:** Internet-facing  
**IP Address Type:** IPv4  
**Region:** `eu-central-1`

### Subnets

**Public Subnets (2 AZ):**
- `kambriq-public-1` (eu-central-1a)
- `kambriq-public-2` (eu-central-1b)

**Raison:** ALB doit être accessible depuis Internet, donc dans des subnets publics.

### Security Group: `kambriq-dev-alb-sg`

**Inbound Rules:**

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | HTTPS from Internet (CloudFront) |
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTP from Internet (redirect to HTTPS) |

**Outbound Rules:**

| Type | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| All | All | All | ECS Security Group | Allow all to ECS tasks |

### Listeners

#### Listener 1: HTTPS (443)

**Protocol:** HTTPS  
**Port:** 443  
**SSL Policy:** `ELBSecurityPolicy-TLS13-1-2-2021-06`  
**Certificate:** ACM Certificate (eu-central-1)

**Default Action:**
- Type: Fixed Response
- Status Code: 404
- Body: "No matching rule"

**Rules (Priority Order):**

1. **Rule 1: `/api/*` → API Target Group**
   - Priority: 1
   - Condition: Path pattern `/api/*`
   - Action: Forward to `kambriq-dev-api-tg`

2. **Rule 2: `/*` → Web Target Group**
   - Priority: 2
   - Condition: Path pattern `/*`
   - Action: Forward to `kambriq-dev-web-tg`

#### Listener 2: HTTP (80)

**Protocol:** HTTP  
**Port:** 80

**Default Action:**
- Type: Redirect
- Protocol: HTTPS
- Port: 443
- Status Code: HTTP_301 (Permanent Redirect)

**Raison:** Forcer HTTPS pour toutes les requêtes HTTP.

### Target Groups

#### Target Group 1: API (`kambriq-dev-api-tg`)

```yaml
Name: kambriq-dev-api-tg
Protocol: HTTP
Port: 8000
Target Type: IP (Fargate)
VPC: kambriq-vpc
Health Check:
  Protocol: HTTP
  Path: /api/health
  Port: 8000
  Interval: 30 seconds
  Timeout: 5 seconds
  Healthy Threshold: 2
  Unhealthy Threshold: 3
  Success Codes: 200
Deregistration Delay: 30 seconds
Stickiness: Disabled
```

**Targets:**
- ECS Tasks from `kambriq-dev-api` service
- IP addresses from private subnets

#### Target Group 2: Web (`kambriq-dev-web-tg`)

```yaml
Name: kambriq-dev-web-tg
Protocol: HTTP
Port: 3000
Target Type: IP (Fargate)
VPC: kambriq-vpc
Health Check:
  Protocol: HTTP
  Path: /health
  Port: 3000
  Interval: 30 seconds
  Timeout: 5 seconds
  Healthy Threshold: 2
  Unhealthy Threshold: 3
  Success Codes: 200
Deregistration Delay: 30 seconds
Stickiness: Disabled
```

**Targets:**
- ECS Tasks from `kambriq-dev-web` service
- IP addresses from private subnets

### ACM Certificate (ALB)

**Region:** `eu-central-1`  
**Domain:** `dev.kambriq.com`  
**Validation:** DNS (Route53)

**Raison:** ALB nécessite un certificat dans la même région (eu-central-1), différent du certificat CloudFront (us-east-1).

---

## 3. ECS Cluster

### Configuration

**Name:** `kambriq-dev-cluster`  
**Launch Type:** Fargate  
**Container Insights:** Enabled

### CloudWatch Logs

**Log Group:** `/ecs/kambriq-dev`  
**Retention:** 7 days

---

## 4. ECS Services

### Service 1: API (FastAPI)

#### Task Definition

```yaml
Family: kambriq-dev-api
Network Mode: awsvpc
Requires Compatibilities: FARGATE
CPU: 256 (0.25 vCPU)
Memory: 512 MB
Execution Role: kambriq-dev-ecs-task-execution
Task Role: kambriq-dev-ecs-task-api
```

#### Container Definition

```yaml
Name: api
Image: 051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev:latest
Essential: true
Port Mappings:
  - ContainerPort: 8000
    Protocol: TCP
Environment Variables:
  - ENV: dev
  - AWS_REGION: eu-central-1
Secrets (from SSM):
  - DATABASE_URL: arn:aws:ssm:eu-central-1:051551940370:parameter/kambriq/dev/db/url
  - JWT_SECRET: arn:aws:ssm:eu-central-1:051551940370:parameter/kambriq/dev/api/JWT_SECRET
Log Configuration:
  Log Driver: awslogs
  Options:
    awslogs-group: /ecs/kambriq-dev-api
    awslogs-region: eu-central-1
    awslogs-stream-prefix: api
Health Check:
  Command: ["CMD-SHELL", "curl -f http://localhost:8000/api/health || exit 1"]
  Interval: 30 seconds
  Timeout: 5 seconds
  Retries: 3
  Start Period: 60 seconds
```

#### Service Configuration

```yaml
Name: kambriq-dev-api
Cluster: kambriq-dev-cluster
Task Definition: kambriq-dev-api
Desired Count: 1
Launch Type: FARGATE
Network Configuration:
  Subnets:
    - kambriq-private-1 (eu-central-1a)
    - kambriq-private-2 (eu-central-1b)
  Security Groups:
    - kambriq-dev-ecs-sg
  Assign Public IP: false
Load Balancer:
  Target Group: kambriq-dev-api-tg
  Container Name: api
  Container Port: 8000
Deployment Configuration:
  Maximum Percent: 200
  Minimum Healthy Percent: 100
Deployment Circuit Breaker:
  Enable: true
  Rollback: true
```

**Subnets:** Private subnets (pas d'IP publique, accès Internet via NAT Gateway)

**Raison:** Sécurité - les containers n'ont pas d'IP publique, seul l'ALB peut les atteindre.

### Service 2: Web (Next.js)

#### Task Definition

```yaml
Family: kambriq-dev-web
Network Mode: awsvpc
Requires Compatibilities: FARGATE
CPU: 256 (0.25 vCPU)
Memory: 512 MB
Execution Role: kambriq-dev-ecs-task-execution
Task Role: kambriq-dev-ecs-task-web
```

#### Container Definition

```yaml
Name: web
Image: 051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-web-dev:latest
Essential: true
Port Mappings:
  - ContainerPort: 3000
    Protocol: TCP
Environment Variables:
  - ENV: dev
  - NEXT_PUBLIC_SITE_URL: https://dev.kambriq.com
  - NEXT_PUBLIC_API_URL: https://dev.kambriq.com/api
Secrets (from SSM):
  - (if needed) NEXT_PUBLIC_* variables
Log Configuration:
  Log Driver: awslogs
  Options:
    awslogs-group: /ecs/kambriq-dev-web
    awslogs-region: eu-central-1
    awslogs-stream-prefix: web
Health Check:
  Command: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
  Interval: 30 seconds
  Timeout: 5 seconds
  Retries: 3
  Start Period: 60 seconds
```

#### Service Configuration

```yaml
Name: kambriq-dev-web
Cluster: kambriq-dev-cluster
Task Definition: kambriq-dev-web
Desired Count: 1
Launch Type: FARGATE
Network Configuration:
  Subnets:
    - kambriq-private-1 (eu-central-1a)
    - kambriq-private-2 (eu-central-1b)
  Security Groups:
    - kambriq-dev-ecs-sg
  Assign Public IP: false
Load Balancer:
  Target Group: kambriq-dev-web-tg
  Container Name: web
  Container Port: 3000
Deployment Configuration:
  Maximum Percent: 200
  Minimum Healthy Percent: 100
Deployment Circuit Breaker:
  Enable: true
  Rollback: true
```

---

## 5. Security Groups

### Security Group 1: ALB (`kambriq-dev-alb-sg`)

**VPC:** `kambriq-vpc`

**Inbound:**
- Port 443 (HTTPS) from `0.0.0.0/0` (Internet/CloudFront)
- Port 80 (HTTP) from `0.0.0.0/0` (Internet/CloudFront)

**Outbound:**
- All traffic to `kambriq-dev-ecs-sg`

### Security Group 2: ECS (`kambriq-dev-ecs-sg`)

**VPC:** `kambriq-vpc`

**Inbound:**
- All traffic from `kambriq-dev-alb-sg` (ALB → ECS)

**Outbound:**
- All traffic to `0.0.0.0/0` (Internet via NAT Gateway)
- Port 5432 (PostgreSQL) to `kambriq-dev-rds-sg` (ECS → RDS)

### Security Group 3: RDS (`kambriq-dev-rds-sg`)

**VPC:** `kambriq-vpc`

**Inbound:**
- Port 5432 (PostgreSQL) from `kambriq-dev-ecs-sg` (ECS → RDS only)

**Outbound:**
- None (RDS n'a pas besoin d'accès sortant)

---

## 6. RDS PostgreSQL

### Configuration

```yaml
Identifier: kambriq-postgres-dev
Engine: postgres
Engine Version: 15.15
Instance Class: db.t4g.micro
Storage:
  Type: gp3
  Size: 20 GB
  Encrypted: true
Database:
  Name: kambriq
  Username: (from SSM/Secrets)
  Password: (from SSM/Secrets)
Network:
  Subnet Group: kambriq-db-subnet-dev (private subnets)
  Security Group: kambriq-dev-rds-sg
  Publicly Accessible: false
Backup:
  Retention Period: 7 days
  Window: 03:00-04:00 UTC
Maintenance:
  Window: Mon:04:00-Mon:05:00 UTC
Multi-AZ: false (dev environment)
```

**Subnets:** Private subnets (2 AZ)  
**Raison:** RDS doit être dans des subnets privés, accessible uniquement depuis ECS.

---

## 7. IAM Roles

### Role 1: ECS Task Execution (`kambriq-dev-ecs-task-execution`)

**Trust Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Policies:**
- `AmazonECSTaskExecutionRolePolicy` (AWS managed)
- Custom: ECR pull permissions
- Custom: CloudWatch Logs write permissions

**Usage:** Utilisé par ECS pour puller les images ECR et écrire les logs.

### Role 2: ECS Task - API (`kambriq-dev-ecs-task-api`)

**Trust Policy:** Same as above

**Policies:**
- SSM Parameter Store read: `/kambriq/dev/api/*`, `/kambriq/dev/db/*`
- RDS describe permissions

**Usage:** Utilisé par le container FastAPI pour accéder aux secrets SSM et RDS.

### Role 3: ECS Task - Web (`kambriq-dev-ecs-task-web`)

**Trust Policy:** Same as above

**Policies:**
- SSM Parameter Store read: `/kambriq/dev/web/*`

**Usage:** Utilisé par le container Next.js pour accéder aux variables publiques SSM.

---

## 8. Flux de Données Détaillé

### Requête 1: `GET https://dev.kambriq.com/api/health`

```
1. Client (Internet)
   ↓ HTTPS Request
   Host: dev.kambriq.com
   Path: /api/health

2. Route53 DNS
   ↓ Resolve dev.kambriq.com
   → CloudFront Distribution (d1234567890.cloudfront.net)

3. CloudFront Distribution
   ↓ Match Path Pattern: /api/*
   → Cache Behavior: /api/* (no cache)
   → Forward to Origin: ALB
   → Headers: X-Forwarded-Host: dev.kambriq.com
   → Protocol: HTTPS

4. ALB (Internet-facing, Public Subnet)
   ↓ HTTPS Listener (443)
   → Match Rule: Priority 1, Path Pattern /api/*
   → Forward to Target Group: kambriq-dev-api-tg

5. Target Group: kambriq-dev-api-tg
   ↓ Health Check: /api/health (200 OK)
   → Select Healthy Target: ECS Task IP (10.0.2.x)
   → Forward Request: HTTP :8000

6. ECS Service: kambriq-dev-api
   ↓ Container: FastAPI (port 8000)
   → Process Request: GET /api/health
   → Response: {"status": "ok", "timestamp": "..."}

7. Response Path (Reverse)
   ↓ ECS → ALB → CloudFront → Client
   → HTTP 200 OK
   → Body: JSON response
```

### Requête 2: `GET https://dev.kambriq.com/` (Homepage)

```
1. Client (Internet)
   ↓ HTTPS Request
   Host: dev.kambriq.com
   Path: /

2. Route53 DNS
   ↓ Resolve dev.kambriq.com
   → CloudFront Distribution

3. CloudFront Distribution
   ↓ Match Path Pattern: /* (default)
   → Cache Behavior: /* (cache static, no cache SSR)
   → Check Cache: Miss (first request)
   → Forward to Origin: ALB

4. ALB
   ↓ HTTPS Listener (443)
   → Match Rule: Priority 2, Path Pattern /*
   → Forward to Target Group: kambriq-dev-web-tg

5. Target Group: kambriq-dev-web-tg
   ↓ Health Check: /health (200 OK)
   → Select Healthy Target: ECS Task IP (10.0.2.y)
   → Forward Request: HTTP :3000

6. ECS Service: kambriq-dev-web
   ↓ Container: Next.js (port 3000)
   → Process Request: GET /
   → SSR: Render page.tsx
   → Response: HTML

7. CloudFront
   ↓ Cache Response (if static assets)
   → Forward to Client

8. Client
   ↓ Receive HTML
   → Render Page
```

### Requête 3: `POST https://dev.kambriq.com/api/auth/login`

```
1-4. Same as Requête 1 (CloudFront → ALB → API Target Group)

5. ECS Service: kambriq-dev-api
   ↓ Container: FastAPI (port 8000)
   → Process Request: POST /api/auth/login
   → Validate Credentials (query RDS)
   → Generate JWT Access Token (15 min)
   → Generate Refresh Token (7 days)
   → Set Cookie: refresh_token (HttpOnly, Secure, SameSite=Lax)
   → Response: {"user": {...}, "accessToken": "..."}

6. Response Path
   ↓ ECS → ALB → CloudFront → Client
   → HTTP 200 OK
   → Set-Cookie: refresh_token=...
   → Body: JSON with accessToken
```

### Requête 4: Database Query (FastAPI → RDS)

```
1. FastAPI Container (ECS Task)
   ↓ Database Query
   → Connection String: (from SSM Parameter Store)
   → Protocol: PostgreSQL
   → Port: 5432

2. Security Group: kambriq-dev-ecs-sg
   ↓ Outbound Rule
   → Allow: Port 5432 to kambriq-dev-rds-sg

3. Security Group: kambriq-dev-rds-sg
   ↓ Inbound Rule
   → Allow: Port 5432 from kambriq-dev-ecs-sg

4. RDS PostgreSQL
   ↓ Process Query
   → Execute SQL
   → Return Results

5. Response Path
   ↓ RDS → ECS → FastAPI
   → Query Results
```

---

## 9. Ports et Protocoles

| Service | Port | Protocol | Direction | Description |
|---------|------|----------|-----------|-------------|
| CloudFront | 443 | HTTPS | Inbound | HTTPS from Internet |
| CloudFront | 80 | HTTP | Inbound | HTTP from Internet (redirect) |
| ALB | 443 | HTTPS | Inbound | HTTPS from CloudFront |
| ALB | 80 | HTTP | Inbound | HTTP from CloudFront (redirect) |
| ALB → ECS API | 8000 | HTTP | Outbound | Forward to FastAPI |
| ALB → ECS Web | 3000 | HTTP | Outbound | Forward to Next.js |
| ECS → RDS | 5432 | PostgreSQL | Outbound | Database queries |
| ECS → Internet | All | All | Outbound | Via NAT Gateway |

---

## 10. Health Checks

### ALB Health Checks

**API Target Group:**
- Path: `/api/health`
- Protocol: HTTP
- Port: 8000
- Interval: 30 seconds
- Timeout: 5 seconds
- Healthy Threshold: 2
- Unhealthy Threshold: 3

**Web Target Group:**
- Path: `/health`
- Protocol: HTTP
- Port: 3000
- Interval: 30 seconds
- Timeout: 5 seconds
- Healthy Threshold: 2
- Unhealthy Threshold: 3

### ECS Container Health Checks

**FastAPI:**
```bash
curl -f http://localhost:8000/api/health || exit 1
```

**Next.js:**
```bash
curl -f http://localhost:3000/health || exit 1
```

---

## 11. Monitoring

### CloudWatch Metrics

**ALB:**
- RequestCount
- TargetResponseTime
- HTTPCode_Target_2XX_Count
- HTTPCode_Target_4XX_Count
- HTTPCode_Target_5XX_Count
- HealthyHostCount
- UnHealthyHostCount

**ECS:**
- CPUUtilization
- MemoryUtilization
- RunningTaskCount
- DesiredTaskCount

**RDS:**
- CPUUtilization
- DatabaseConnections
- FreeableMemory
- FreeStorageSpace

### CloudWatch Logs

**Log Groups:**
- `/ecs/kambriq-dev-api` (FastAPI logs)
- `/ecs/kambriq-dev-web` (Next.js logs)
- `/ecs/kambriq-dev` (Cluster logs)

### Alarms (Recommandés)

1. **ALB 5xx Errors > 10 in 5 minutes**
2. **ECS CPU > 70% for 5 minutes**
3. **ECS Memory > 80% for 5 minutes**
4. **RDS CPU > 80% for 5 minutes**
5. **Unhealthy Hosts > 0 for 2 minutes**

---

## 12. Certificats ACM

### Certificat 1: CloudFront (us-east-1)

**ARN:** `arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f`  
**Region:** `us-east-1` (requis pour CloudFront)  
**Domain:** `dev.kambriq.com`  
**Validation:** DNS (Route53)

### Certificat 2: ALB (eu-central-1)

**ARN:** (à créer ou réutiliser existant)  
**Region:** `eu-central-1` (même région que ALB)  
**Domain:** `dev.kambriq.com`  
**Validation:** DNS (Route53)

**Raison:** CloudFront et ALB nécessitent des certificats séparés dans leurs régions respectives.

---

## 13. VPC et Subnets

### VPC

**CIDR:** `10.0.0.0/16`  
**DNS Support:** Enabled  
**DNS Hostnames:** Enabled

### Subnets

**Public Subnets (2 AZ):**
- `kambriq-public-1`: `10.0.0.0/24` (eu-central-1a) - ALB
- `kambriq-public-2`: `10.0.1.0/24` (eu-central-1b) - ALB

**Private Subnets (2 AZ):**
- `kambriq-private-1`: `10.0.2.0/24` (eu-central-1a) - ECS, RDS
- `kambriq-private-2`: `10.0.3.0/24` (eu-central-1b) - ECS, RDS

**RDS Subnet Group:**
- `kambriq-private-1` (eu-central-1a)
- `kambriq-private-2` (eu-central-1b)

### NAT Gateway

**Location:** Public Subnet (eu-central-1a)  
**Purpose:** Permet aux ressources des private subnets d'accéder à Internet (pour ECR pull, SSM, etc.)

---

## 14. ECR Repositories

### Repository 1: API

**Name:** `kambriq-api-dev`  
**URI:** `051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev`  
**Image Tag:** `latest` (ou SHA commit)

### Repository 2: Web

**Name:** `kambriq-web-dev`  
**URI:** `051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-web-dev`  
**Image Tag:** `latest` (ou SHA commit)

---

## 15. SSM Parameter Store

### Parameters Requis

```
/kambriq/dev/api/JWT_SECRET          (SecureString)
/kambriq/dev/db/url                  (SecureString)
/kambriq/dev/web/NEXT_PUBLIC_*       (String, if needed)
```

**Access:**
- ECS Task Role (API): Read `/kambriq/dev/api/*`, `/kambriq/dev/db/*`
- ECS Task Role (Web): Read `/kambriq/dev/web/*`

---

## 16. Résumé des Flux

### Flux Principal (Requête Utilisateur)

```
Internet
  ↓ HTTPS (443)
CloudFront (dev.kambriq.com)
  ↓ HTTPS (443) - Custom Origin
ALB (Public Subnet)
  ↓ HTTP (8000 ou 3000) - Target Group
ECS Fargate (Private Subnet)
  ├─ FastAPI :8000
  └─ Next.js :3000
       ↓ PostgreSQL (5432)
    RDS (Private Subnet)
```

### Flux de Réponse

```
RDS → ECS → ALB → CloudFront → Internet → Client
```

### Flux de Logs

```
ECS Containers → CloudWatch Logs (/ecs/kambriq-dev-*)
```

### Flux de Monitoring

```
ALB/ECS/RDS → CloudWatch Metrics → Alarms → SNS (optional)
```

---

## 17. Points Clés de Sécurité

1. **Pas d'IP Publique pour ECS:** Containers dans private subnets, accessibles uniquement via ALB
2. **Security Groups Stricts:** Seulement les connexions nécessaires sont autorisées
3. **HTTPS Partout:** CloudFront → ALB → (HTTP interne OK car même VPC)
4. **Secrets dans SSM:** Jamais dans le code ou variables d'environnement en clair
5. **IAM Roles Minimaux:** Chaque service a uniquement les permissions nécessaires
6. **RDS Privé:** Accessible uniquement depuis ECS, pas depuis Internet

---

## 18. Configuration Terraform

Le certificat CloudFront est déjà configuré dans `envs/dev-v2/main.tf`:

```hcl
variable "cloudfront_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront (us-east-1)"
  type        = string
  default     = "arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f"
}
```

**À faire:** Mettre à jour `terraform.tfvars` avec cette valeur.

---

Cette architecture garantit:
- ✅ Haute disponibilité (multi-AZ)
- ✅ Sécurité (private subnets, security groups stricts)
- ✅ Scalabilité (ECS auto-scaling, ALB load balancing)
- ✅ Performance (CloudFront CDN, cache optimisé)
- ✅ Observabilité (CloudWatch logs et metrics)

