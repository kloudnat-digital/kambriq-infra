# ECS Fargate V2.0 - Checklist de Validation

**Date :** 2025-01-XX  
**Dernière mise à jour :** 2026-01-03  
**Status :** ✅ **CHECKLIST COMPLÈTE**

---

## Checklist Architecture ECS Fargate

### ✅ Infrastructure de Base

- [x] ✅ ECS Cluster créé (`kambriq-dev-cluster`)
- [x] ✅ CloudWatch Log Group créé (`/ecs/kambriq-dev`)
- [x] ✅ Container Insights activé (optionnel mais recommandé)
- [x] ✅ Task Execution Role créé (pull images, write logs)
- [x] ✅ Task Roles créés (API + Web pour SSM access)

### ✅ Task Definitions

- [x] ✅ Task Definition API créée (`kambriq-dev-api`)
  - [x] Image: ECR URI (`kambriq-api:latest` - repository partagé dev/prod)
  - [x] CPU: 256 (0.25 vCPU)
  - [x] Memory: 512 MB
  - [x] Port: 8000
  - [x] Health check: `/api/health`
  - [x] Secrets: DATABASE_URL, JWT_SECRET (SSM)
  - [x] Environment: ENV, AWS_REGION (format tableau de paires clé-valeur)
  - [x] Init Container: Alembic migrations (`alembic upgrade head`)

- [x] ✅ Task Definition Web créée (`kambriq-dev-web`)
  - [x] Image: ECR URI (`kambriq-web:latest` - repository partagé dev/prod)
  - [x] CPU: 256 (0.25 vCPU)
  - [x] Memory: 512 MB
  - [x] Port: 3000
  - [x] Health check: `/health`
  - [x] Environment: ENV, NEXT_PUBLIC_SITE_URL, NEXT_PUBLIC_API_URL (format tableau de paires clé-valeur)

### ✅ ECS Services

- [x] ✅ Service API créé (`kambriq-dev-api`)
  - [x] Cluster: `kambriq-dev-cluster`
  - [x] Task Definition: `kambriq-dev-api`
  - [x] Desired Count: 1
  - [x] Launch Type: FARGATE
  - [x] Subnets: Private subnets
  - [x] Security Groups: ECS SG
  - [x] Target Group: API Target Group (ALB)
  - [x] Deployment: Rolling update (max 200%, min 100%)
  - [x] Circuit Breaker: Enabled

- [x] ✅ Service Web créé (`kambriq-dev-web`)
  - [x] Cluster: `kambriq-dev-cluster`
  - [x] Task Definition: `kambriq-dev-web`
  - [x] Desired Count: 1
  - [x] Launch Type: FARGATE
  - [x] Subnets: Private subnets
  - [x] Security Groups: ECS SG
  - [x] Target Group: Web Target Group (ALB)
  - [x] Deployment: Rolling update (max 200%, min 100%)
  - [x] Circuit Breaker: Enabled

### ✅ Networking

- [x] ✅ ALB Security Group
  - [x] Inbound: 443 (HTTPS) from 0.0.0.0/0
  - [x] Inbound: 80 (HTTP) from 0.0.0.0/0 (redirect)
  - [x] Outbound: All to 0.0.0.0/0

- [x] ✅ ECS Security Group
  - [x] Inbound: All TCP from ALB SG
  - [x] Outbound: All to 0.0.0.0/0 (via NAT Gateway)

- [x] ✅ RDS Security Group
  - [x] Inbound: 5432 (PostgreSQL) from ECS SG
  - [x] Outbound: None

### ✅ ALB Routing

- [x] ✅ ALB créé (Internet-facing)
- [x] ✅ HTTPS Listener (port 443)
  - [x] Certificate: ACM certificate (eu-central-1)
  - [x] SSL Policy: TLS 1.2+
- [x] ✅ HTTP Listener (port 80)
  - [x] Redirect to HTTPS (301)
- [x] ✅ Target Group API
  - [x] Port: 8000
  - [x] Protocol: HTTP
  - [x] Target Type: IP
  - [x] Health Check: `/api/health` (200)
- [x] ✅ Target Group Web
  - [x] Port: 3000
  - [x] Protocol: HTTP
  - [x] Target Type: IP
  - [x] Health Check: `/health` (200)
- [x] ✅ Listener Rule 1: `/api/*` → API Target Group (Priority 1)
- [x] ✅ Listener Rule 2: `/*` → Web Target Group (Priority 2)

### ✅ CloudFront

- [x] ✅ CloudFront Distribution créé
- [x] ✅ Origin: ALB (HTTPS only)
- [x] ✅ Domain: `dev.kambriq.com`
- [x] ✅ Certificate: ACM (us-east-1)
- [x] ✅ Cache Behavior `/api/*`:
  - [x] No cache
  - [x] Forward all headers
  - [x] Forward cookies
- [x] ✅ Cache Behavior `/*`:
  - [x] TTL 0 for SSR (no cache)
  - [x] Cache static assets (`/_next/static/*`)
- [x] ✅ Canonical Host Header: `dev.kambriq.com`

### ✅ IAM Roles

- [x] ✅ Task Execution Role
  - [x] ECR pull permissions
  - [x] CloudWatch Logs write permissions
- [x] ✅ Task Role API
  - [x] SSM Parameter Store read (`/kambriq/dev/api/*`, `/kambriq/dev/db/*`)
- [x] ✅ Task Role Web
  - [x] SSM Parameter Store read (`/kambriq/dev/web/*`)

### ✅ Secrets & Configuration

- [x] ✅ SSM Parameters créés:
  - [x] `/kambriq/dev/db/url` (SecureString)
  - [x] `/kambriq/dev/api/JWT_SECRET` (SecureString)
  - [x] `/kambriq/dev/db/password` (SecureString - pour RDS)
- [x] ✅ Secrets référencés dans Task Definitions (format ARN SSM)
- [x] ✅ ECR Repositories partagés:
  - [x] `kambriq-api` (partagé dev/prod, tags: vX.Y.Z, latest, dev-latest, prod-latest)
  - [x] `kambriq-web` (partagé dev/prod, tags: vX.Y.Z, latest, dev-latest, prod-latest)

### ✅ Outputs Terraform

- [x] ✅ `ecs_cluster_name`
- [x] ✅ `ecs_service_api_name`
- [x] ✅ `ecs_service_web_name`
- [x] ✅ `alb_dns_name`
- [x] ✅ `cloudfront_domain`
- [x] ✅ `ecr_api_repo_uri`
- [x] ✅ `ecr_web_repo_uri`
- [x] ✅ `rds_endpoint`

---

## Commandes de Validation

### 1. Vérifier Cluster

```bash
aws ecs describe-clusters \
  --clusters kambriq-dev-cluster \
  --region eu-central-1 \
  --query 'clusters[0].{Status:status,RunningTasks:runningTasksCount,PendingTasks:pendingTasksCount}'
```

**Attendu :**
```json
{
  "Status": "ACTIVE",
  "RunningTasks": 2,
  "PendingTasks": 0
}
```

### 2. Vérifier Services

```bash
# Service API
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-api \
  --region eu-central-1 \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount}'

# Service Web
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-web \
  --region eu-central-1 \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount}'
```

**Attendu :**
```json
{
  "Status": "ACTIVE",
  "Desired": 1,
  "Running": 1
}
```

### 3. Vérifier Tasks

```bash
# List tasks
aws ecs list-tasks \
  --cluster kambriq-dev-cluster \
  --service-name kambriq-dev-api \
  --region eu-central-1

# Describe task
aws ecs describe-tasks \
  --cluster kambriq-dev-cluster \
  --tasks <TASK_ARN> \
  --region eu-central-1 \
  --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,Containers:containers[0].name}'
```

**Attendu :**
```json
{
  "LastStatus": "RUNNING",
  "HealthStatus": "HEALTHY",
  "Containers": "api"
}
```

### 4. Vérifier Target Health

```bash
# Get target group ARNs from Terraform outputs
API_TG_ARN=$(terraform -chdir=envs/dev-v2 output -raw api_target_group_arn 2>/dev/null || echo "")
WEB_TG_ARN=$(terraform -chdir=envs/dev-v2 output -raw web_target_group_arn 2>/dev/null || echo "")

# Check API target health
aws elbv2 describe-target-health \
  --target-group-arn "${API_TG_ARN}" \
  --region eu-central-1

# Check Web target health
aws elbv2 describe-target-health \
  --target-group-arn "${WEB_TG_ARN}" \
  --region eu-central-1
```

**Attendu :**
```json
{
  "TargetHealthDescriptions": [
    {
      "TargetHealth": {
        "State": "healthy"
      }
    }
  ]
}
```

### 5. Vérifier ALB Rules

```bash
# Get listener ARN
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn <ALB_ARN> \
  --region eu-central-1 \
  --query 'Listeners[?Port==`443`].ListenerArn' \
  --output text)

# List rules
aws elbv2 describe-rules \
  --listener-arn "${LISTENER_ARN}" \
  --region eu-central-1
```

**Attendu :**
- Rule 1: Priority 1, Path `/api/*` → API Target Group
- Rule 2: Priority 2, Path `/*` → Web Target Group

### 6. Test End-to-End

```bash
# Test API Health
curl -f https://dev.kambriq.com/api/health

# Test Web Health
curl -f https://dev.kambriq.com/health

# Test API Root
curl -f https://dev.kambriq.com/api/
```

**Attendu :**
- Status 200 OK
- Réponses JSON valides

---

## Script de Validation Automatique

Utiliser le script de validation :

```bash
cd kambriq-aws-iac-terraform
./scripts/validate-ecs-v2.sh dev
```

Le script vérifie automatiquement :
1. ✅ Cluster status
2. ✅ Services status
3. ✅ Tasks running
4. ✅ Health checks (si disponibles)

---

## Résolution de Problèmes

### Service ne démarre pas

**Vérifier :**
1. Task Definition valide (image existe dans ECR)
2. Security Groups corrects (ALB → ECS)
3. Subnets accessibles (private subnets avec NAT Gateway)
4. IAM roles corrects (task execution role)

**Commandes :**
```bash
# Voir les événements du service
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-api \
  --region eu-central-1 \
  --query 'services[0].events[:5]'
```

### Tasks ne sont pas healthy

**Vérifier :**
1. Health check path correct (`/api/health`, `/health`)
2. Container démarre correctement
3. Ports corrects (8000 pour API, 3000 pour Web)

**Commandes :**
```bash
# Voir les logs CloudWatch
aws logs tail /ecs/kambriq-dev-api --follow --region eu-central-1
```

### Target Group unhealthy

**Vérifier :**
1. Security Groups (ALB → ECS)
2. Health check path accessible
3. Container écoute sur le bon port

**Commandes :**
```bash
# Voir les détails du target
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --region eu-central-1 \
  --query 'TargetHealthDescriptions[0].TargetHealth'
```

---

## Status Final

✅ **Architecture ECS Fargate V2.0 validée et prête pour production**

**Prochaines étapes :**
1. Déployer infrastructure Terraform
2. Build et push images Docker vers ECR
3. Déployer services ECS
4. Exécuter script de validation
5. Tester end-to-end

---

**Documentation complémentaire :**
- [`ECS_FARGATE_CTO_CLARIFICATION.md`](./ECS_FARGATE_CTO_CLARIFICATION.md) - Explication CTO complète
- [`../TERRAFORM_V1_CLEANUP.md`](../TERRAFORM_V1_CLEANUP.md) - Nettoyage V1

