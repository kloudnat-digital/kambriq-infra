# Bootstrap KAMBRIQ v2.0 Infrastructure

## Prérequis

- AWS CLI configuré avec credentials
- Terraform >= 1.6.0
- Accès au bucket S3 `kloudnat-infra-shared-store`
- Accès au Route53 hosted zone `kambriq.com`

## Étapes de Bootstrap

### 1. Vérifier Infrastructure Shared

L'infrastructure shared doit être déployée en premier:

```bash
cd kambriq-aws-iac-terraform/envs/shared
terraform init
terraform plan
terraform apply
```

**Outputs requis:**
- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`
- `route53_zone_id`
- `api_certificate_arn`

### 2. Créer Certificat ACM pour CloudFront (us-east-1)

CloudFront nécessite un certificat ACM dans la région `us-east-1`:

```bash
# Créer certificat dans us-east-1
aws acm request-certificate \
  --domain-name dev.kambriq.com \
  --validation-method DNS \
  --region us-east-1

# Noter l'ARN du certificat (à utiliser dans terraform.tfvars)
```

**Important:** Valider le certificat via DNS dans Route53 avant de continuer.

### 3. Configurer Variables

Copier `terraform.tfvars.example` et remplir les valeurs:

```bash
cd kambriq-aws-iac-terraform/envs/dev-v2
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars
```

**Variables requises:**
- `db_username`: Username RDS
- `db_password`: Password RDS (secure)
- `cloudfront_certificate_arn`: ARN du certificat ACM us-east-1

### 4. Initialiser Terraform

```bash
terraform init
```

### 5. Plan et Apply

```bash
# Vérifier le plan
terraform plan

# Appliquer (créer infrastructure)
terraform apply
```

**Ressources créées:**
- ECR repositories (api, web)
- ECS Cluster
- ALB avec target groups
- CloudFront distribution
- RDS PostgreSQL
- ECS Services (API + Web)
- Security Groups
- IAM Roles

### 6. Vérifier Outputs

```bash
terraform output
```

**Outputs importants:**
- `cloudfront_domain`: Domain CloudFront
- `alb_dns_name`: DNS ALB
- `ecr_api_repo_uri`: URI ECR pour API
- `ecr_web_repo_uri`: URI ECR pour Web
- `rds_endpoint`: Endpoint RDS

### 7. Configurer DNS

Le module crée automatiquement le record Route53 pour `dev.kambriq.com` pointant vers CloudFront.

Vérifier:
```bash
dig dev.kambriq.com
```

### 8. Build et Push Images Docker

```bash
# API
cd kambriq/apps/api
docker build -t $(terraform output -raw ecr_api_repo_uri):latest .
docker push $(terraform output -raw ecr_api_repo_uri):latest

# Web
cd kambriq/apps/web
docker build -t $(terraform output -raw ecr_web_repo_uri):latest .
docker push $(terraform output -raw ecr_web_repo_uri):latest
```

### 9. Activer Services ECS

Par défaut, les services ECS sont créés avec `desired_count = 1`. Si vous voulez les démarrer plus tard:

```bash
aws ecs update-service \
  --cluster kambriq-dev-cluster \
  --service kambriq-dev-api \
  --desired-count 1 \
  --region eu-central-1

aws ecs update-service \
  --cluster kambriq-dev-cluster \
  --service kambriq-dev-web \
  --desired-count 1 \
  --region eu-central-1
```

### 10. Tests de Validation

```bash
# Attendre que les services soient stables
aws ecs wait services-stable \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-api kambriq-dev-web \
  --region eu-central-1

# Tests health
curl https://dev.kambriq.com/api/health
curl https://dev.kambriq.com/health
```

## Dépannage

### ECS Tasks ne démarrent pas

1. Vérifier logs CloudWatch:
   ```bash
   aws logs tail /ecs/kambriq-dev-api --follow
   ```

2. Vérifier security groups (ALB → ECS, ECS → RDS)

3. Vérifier IAM roles (task execution, task role)

### ALB Health Checks échouent

1. Vérifier que les containers écoutent sur les bons ports (8000 API, 3000 Web)

2. Vérifier health check paths:
   - API: `/api/health`
   - Web: `/health`

3. Vérifier security group ALB → ECS

### CloudFront ne fonctionne pas

1. Vérifier certificat ACM (doit être validé)

2. Vérifier DNS (dev.kambriq.com doit pointer vers CloudFront)

3. Vérifier origin ALB (doit être accessible)

## Prochaines Étapes

1. Configurer SSM Parameters (si pas déjà fait)
2. Déployer applications via CI/CD
3. Configurer monitoring et alarms
4. Tester migration V1 → V2

