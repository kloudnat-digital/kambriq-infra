# ECS Fargate Architecture - CTO Clarification

**Date :** 2025-01-XX  
**Auteur :** Principal Architect / CTO  
**Status :** ✅ **ARCHITECTURE V2.0 VALIDÉE**

---

## ⚠️ Clarification Importante : ECS Fargate ≠ Kubernetes

### ECS Fargate est Serverless Container Compute

**ECS Fargate** est un service AWS **serverless** pour exécuter des conteneurs Docker. Il ne nécessite **aucune gestion de serveurs, nodes, ou clusters Kubernetes**.

**Points clés :**
- ✅ **Pas de nodes à administrer** : AWS gère l'infrastructure sous-jacente
- ✅ **Pas de Kubernetes** : ECS est un orchestrateur natif AWS, plus simple
- ✅ **Fargate = compute serverless** : Vous payez uniquement pour les ressources CPU/mémoire utilisées
- ✅ **Cluster = namespace logique** : Le cluster ECS est juste un groupement logique, pas un ensemble de machines

---

## Architecture ECS Fargate KAMBRIQ v2.0

### Composants Requis

```
┌─────────────────────────────────────────────────────────┐
│                    ECS CLUSTER                          │
│  (Namespace logique - pas de machines à gérer)          │
└────────────────────┬──────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼────────┐      ┌────────▼────────┐
│  ECS SERVICE    │      │  ECS SERVICE    │
│  FastAPI (API)  │      │  Next.js (Web)  │
└───────┬────────┘      └────────┬────────┘
        │                         │
        │  Task Definition        │  Task Definition
        │  - Image: ECR          │  - Image: ECR
        │  - CPU: 256             │  - CPU: 256
        │  - Memory: 512          │  - Memory: 512
        │  - Port: 8000           │  - Port: 3000
        │                         │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │   FARGATE (Serverless)  │
        │   - AWS gère tout       │
        │   - Pas de nodes        │
        │   - Auto-scaling        │
        └─────────────────────────┘
```

### 1. ECS Cluster (Namespace Logique)

**Rôle :** Groupement logique pour organiser les services ECS.

**Caractéristiques :**
- ✅ **Pas de machines** : C'est juste un "conteneur logique"
- ✅ **Obligatoire** : Même minimal, un cluster est requis pour créer des services
- ✅ **CloudWatch Logs** : Logs centralisés pour tous les services du cluster
- ✅ **Container Insights** : Métriques et monitoring (optionnel)

**Terraform :**
```hcl
resource "aws_ecs_cluster" "main" {
  name = "kambriq-dev-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

**Pourquoi le cluster est obligatoire :**
- AWS ECS nécessite un cluster pour regrouper les services
- Même si vous n'administrez pas de nodes (Fargate), le cluster est le "namespace"
- C'est l'équivalent d'un "projet" ou "namespace" dans Kubernetes, mais sans la complexité

---

### 2. Task Definition (Configuration Container)

**Rôle :** Définit **comment** exécuter un conteneur.

**Contient :**
- Image Docker (ECR)
- CPU et mémoire alloués
- Variables d'environnement
- Secrets (SSM Parameter Store)
- Ports exposés
- Health checks
- IAM roles (execution + task)

**Terraform :**
```hcl
resource "aws_ecs_task_definition" "api" {
  family                   = "kambriq-dev-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "..."
  task_role_arn            = "..."
  
  container_definitions = jsonencode([{
    name  = "api"
    image = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev:latest"
    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]
    environment = [...]
    secrets     = [...]
  }])
}
```

**Points clés :**
- ✅ **FARGATE** : Spécifie que nous utilisons Fargate (pas EC2)
- ✅ **awsvpc** : Mode réseau (chaque task a sa propre IP dans le VPC)
- ✅ **CPU/Memory** :** Limites allouées (256 CPU = 0.25 vCPU, 512 MB RAM)

---

### 3. ECS Service (Orchestration + Scaling)

**Rôle :** Gère le déploiement, le scaling et la haute disponibilité.

**Fonctionnalités :**
- ✅ **Desired Count** : Nombre de tasks à maintenir
- ✅ **Auto-scaling** : Ajuste automatiquement le nombre de tasks
- ✅ **Deployment** : Rolling updates (blue/green)
- ✅ **Health checks** : Redémarre les tasks non saines
- ✅ **Load balancer** : Intégration avec ALB target groups

**Terraform :**
```hcl
resource "aws_ecs_service" "api" {
  name            = "kambriq-dev-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8000
  }
}
```

**Points clés :**
- ✅ **FARGATE launch_type** : Utilise Fargate (pas EC2)
- ✅ **Private subnets** : Tasks dans subnets privés (pas d'IP publique)
- ✅ **ALB integration** : Chaque task est enregistrée dans le target group ALB

---

### 4. IAM Roles (2 rôles par service)

#### Task Execution Role (Pull images, write logs)

**Rôle :** Utilisé par ECS pour :
- Puller les images depuis ECR
- Écrire les logs dans CloudWatch

**Permissions :**
- `ecr:GetAuthorizationToken`
- `ecr:BatchGetImage`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

#### Task Role (Permissions applicatives)

**Rôle :** Utilisé par l'application (FastAPI/Next.js) pour :
- Lire les secrets depuis SSM Parameter Store
- Accéder à d'autres services AWS si nécessaire

**Permissions :**
- `ssm:GetParameter` (pour secrets)
- Autres permissions selon besoins

---

## Pourquoi ECS Fargate et pas Kubernetes ?

### Avantages ECS Fargate

1. ✅ **Simplicité** : Pas de nodes à gérer, pas de cluster Kubernetes complexe
2. ✅ **Serverless** : Payez uniquement pour ce que vous utilisez
3. ✅ **Intégration AWS native** : ALB, CloudWatch, IAM, SSM
4. ✅ **Moins de maintenance** : AWS gère l'infrastructure
5. ✅ **Démarrage rapide** : Pas besoin de configurer un cluster Kubernetes

### Comparaison

| Aspect | ECS Fargate | Kubernetes (EKS) |
|--------|-------------|------------------|
| **Complexité** | Faible | Élevée |
| **Nodes à gérer** | ❌ Non (serverless) | ✅ Oui (ou EKS Fargate) |
| **Coût** | Pay-as-you-go | Plus cher (nodes + cluster) |
| **Courbe d'apprentissage** | Faible | Élevée |
| **Intégration AWS** | Native | Via plugins |
| **Maintenance** | Minimale | Élevée |

**Décision CTO :** ECS Fargate est le choix optimal pour KAMBRIQ v2.0 car :
- ✅ Stack AWS native (pas de dépendances externes)
- ✅ Maintenance minimale
- ✅ Coûts prévisibles
- ✅ Scaling automatique simple

---

## Architecture Complète KAMBRIQ v2.0

```
Internet
   │
   │ HTTPS (443)
   ▼
CloudFront (dev.kambriq.com)
   │
   │ HTTPS (443)
   ▼
ALB (Application Load Balancer)
   │
   ├─ /api/* → Target Group API (port 8000)
   │            │
   │            ▼
   │         ECS Service: FastAPI
   │         - Task Definition: kambriq-dev-api
   │         - Desired Count: 1
   │         - Fargate: 256 CPU, 512 MB
   │
   └─ /* → Target Group Web (port 3000)
            │
            ▼
         ECS Service: Next.js
         - Task Definition: kambriq-dev-web
         - Desired Count: 1
         - Fargate: 256 CPU, 512 MB

ECS Cluster: kambriq-dev-cluster
├─ Service: FastAPI
│  └─ Tasks (Fargate)
│     └─ Container: FastAPI (port 8000)
│
└─ Service: Next.js
   └─ Tasks (Fargate)
      └─ Container: Next.js (port 3000)

RDS PostgreSQL (private subnet)
└─ Accessible depuis ECS tasks via security groups
```

---

## Tableau Récapitulatif ECS

| Composant | Type | Rôle | Terraform Resource |
|-----------|------|------|-------------------|
| **Cluster** | Namespace logique | Regroupe les services | `aws_ecs_cluster` |
| **Task Definition** | Configuration | Définit le conteneur | `aws_ecs_task_definition` |
| **Service** | Orchestrateur | Gère scaling + deployment | `aws_ecs_service` |
| **Task** | Instance runtime | Conteneur en cours d'exécution | Créé automatiquement par le service |
| **Task Execution Role** | IAM Role | Pull images, write logs | `aws_iam_role` + policies |
| **Task Role** | IAM Role | Permissions applicatives | `aws_iam_role` + policies |

---

## Validation Architecture

### Checklist CTO

- [x] ✅ ECS Cluster créé (namespace logique)
- [x] ✅ Task Definitions créées (API + Web)
- [x] ✅ ECS Services créés (API + Web)
- [x] ✅ IAM Roles configurés (execution + task)
- [x] ✅ ALB routing configuré (/api/* → API, /* → Web)
- [x] ✅ Security Groups configurés (ALB → ECS → RDS)
- [x] ✅ CloudFront configuré (ALB origin)
- [x] ✅ Health checks configurés (/api/health, /health)
- [x] ✅ Secrets SSM configurés (DATABASE_URL, JWT_SECRET)
- [x] ✅ CloudWatch Logs configurés

---

## Commandes AWS CLI de Validation

### 1. Vérifier Cluster

```bash
aws ecs describe-clusters --clusters kambriq-dev-cluster --region eu-central-1
```

**Attendu :**
- `status: ACTIVE`
- `runningTasksCount: 2` (1 API + 1 Web)
- `pendingTasksCount: 0`

### 2. Vérifier Services

```bash
# Service API
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-api \
  --region eu-central-1

# Service Web
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-web \
  --region eu-central-1
```

**Attendu :**
- `status: ACTIVE`
- `desiredCount: 1`
- `runningCount: 1`
- `deployments[0].status: PRIMARY`

### 3. Vérifier Tasks

```bash
# Tasks API
aws ecs list-tasks \
  --cluster kambriq-dev-cluster \
  --service-name kambriq-dev-api \
  --region eu-central-1

# Détails d'une task
aws ecs describe-tasks \
  --cluster kambriq-dev-cluster \
  --tasks <TASK_ARN> \
  --region eu-central-1
```

**Attendu :**
- `lastStatus: RUNNING`
- `healthStatus: HEALTHY` (si health check configuré)
- `containers[0].name: api`
- `containers[0].image: <ECR_URI>:latest`

### 4. Vérifier Target Health (ALB)

```bash
# Target Group API
aws elbv2 describe-target-health \
  --target-group-arn <API_TG_ARN> \
  --region eu-central-1

# Target Group Web
aws elbv2 describe-target-health \
  --target-group-arn <WEB_TG_ARN> \
  --region eu-central-1
```

**Attendu :**
- `TargetHealth.State: healthy`
- `TargetHealth.Description: Target registration is in progress` (puis `healthy`)

### 5. Vérifier Routes ALB

```bash
# Listener rules
aws elbv2 describe-rules \
  --listener-arn <HTTPS_LISTENER_ARN> \
  --region eu-central-1
```

**Attendu :**
- Rule 1: Priority 1, Path `/api/*` → API Target Group
- Rule 2: Priority 2, Path `/*` → Web Target Group

### 6. Test End-to-End

```bash
# Test API
curl -f https://dev.kambriq.com/api/health

# Test Web
curl -f https://dev.kambriq.com/health

# Test API root
curl -f https://dev.kambriq.com/api/
```

**Attendu :**
- Status 200 OK
- Réponses JSON valides

---

## Conclusion

✅ **Architecture ECS Fargate validée** : L'implémentation Terraform respecte le design V2.0.

**Points clés à retenir :**
1. ✅ ECS Cluster = namespace logique (obligatoire mais pas de machines)
2. ✅ Fargate = compute serverless (AWS gère tout)
3. ✅ Task Definition = configuration conteneur
4. ✅ ECS Service = orchestration + scaling
5. ✅ Pas de Kubernetes : ECS est plus simple et natif AWS

**Status :** ✅ **ARCHITECTURE PRÊTE POUR PRODUCTION**

