# Guide de Déploiement Terraform - KAMBRIQ v2.0

## 📋 Prérequis

### 1. AWS CLI configuré
```bash
aws configure
# Ou utiliser des variables d'environnement:
# export AWS_ACCESS_KEY_ID=...
# export AWS_SECRET_ACCESS_KEY=...
```

### 2. Terraform installé
```bash
terraform version  # Doit être >= 1.5.0
```

### 3. Backend S3
Le bucket `kloudnat-infra-shared-store` doit exister (créé automatiquement par les scripts).

---

## 🚀 Déploiement - Ordre Obligatoire

### Étape 1 : Déployer SHARED (Infrastructure Partagée)

**⚠️ IMPORTANT :** SHARED doit être déployé **EN PREMIER** avant dev-v2.

```bash
cd kambriq-aws-iac-terraform

# Option 1 : Script automatisé
./scripts/terraform-deploy-shared.sh

# Option 2 : Manuel
cd envs/shared
terraform init
terraform plan
terraform apply
```

**Configuration requise (`envs/shared/terraform.tfvars`) :**
```hcl
aws_region = "eu-central-1"
project_name = "kambriq"

# Route53 (optionnel - peut être configuré manuellement après)
route53_zone_id = "Z1234567890ABC"

# SES (optionnel - peut être configuré manuellement après)
ses_domain_identity_arn = "arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/kambriq.com"
ses_email_identity_arn = "arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/noreply@kambriq.com"

# ACM Certificates (optionnel - peut être configuré manuellement après)
acm_alb_certificate_arn = "arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/..."
acm_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/..."
```

**Ressources créées :**
- VPC (10.0.0.0/16)
- Subnets publics/privés
- Internet Gateway
- NAT Gateway
- Route53 hosted zone (référence)
- SES identities (référence)
- ACM certificates (référence)
- S3 buckets (logs, artifacts)

---

### Étape 2 : Configurer Manuellement (si nécessaire)

Après le déploiement de SHARED, configurez manuellement :

1. **Route53 Hosted Zone** pour `kambriq.com`
   - Créer dans AWS Console
   - Récupérer le `zone_id`
   - Ajouter dans `terraform.tfvars` si pas déjà fait

2. **SES Domain Identity** pour `kambriq.com`
   - Créer et vérifier via DNS
   - Récupérer l'ARN
   - Ajouter dans `terraform.tfvars` si pas déjà fait

3. **SES Email Identity** pour `noreply@kambriq.com`
   - Créer et vérifier via email
   - Récupérer l'ARN
   - Ajouter dans `terraform.tfvars` si pas déjà fait

4. **ACM Certificate** pour ALB (eu-central-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN
   - Ajouter dans `terraform.tfvars` si pas déjà fait

5. **ACM Certificate** pour CloudFront (us-east-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN
   - Ajouter dans `envs/dev-v2/terraform.tfvars`

---

### Étape 3 : Déployer DEV-V2 (Environnement Développement)

**⚠️ IMPORTANT :** DEV-V2 dépend de SHARED (consomme les outputs via `terraform_remote_state`).

```bash
cd kambriq-aws-iac-terraform

# Option 1 : Script automatisé
./scripts/terraform-deploy-dev-v2.sh

# Option 2 : Manuel
cd envs/dev-v2
terraform init
terraform plan
terraform apply
```

**Configuration requise (`envs/dev-v2/terraform.tfvars`) :**
```hcl
aws_region = "eu-central-1"
project_name = "kambriq"
env = "dev"

# CloudFront Certificate (us-east-1)
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/..."
```

**Ressources créées :**
- RDS PostgreSQL (t4g.micro, 20GB)
- ECS Cluster (Fargate)
- ECS Services (API + Web)
- ALB (Application Load Balancer)
- CloudFront Distribution
- ECR Repositories (kambriq-api, kambriq-web)
- IAM Roles et Policies
- Security Groups
- SSM Parameters (secrets)

---

### Étape 4 : Générer les Secrets SSM

Après le déploiement de DEV-V2, générez les secrets :

```bash
cd kambriq-aws-iac-terraform
./scripts/generate-and-store-secrets.sh dev
```

**Secrets créés :**
- `/kambriq/dev/db/url` - Database connection string
- `/kambriq/dev/api/JWT_SECRET` - JWT secret
- `/kambriq/dev/api/SES_FROM_EMAIL` - Email expéditeur

---

### Étape 5 : Déployer l'Application

Une fois l'infrastructure déployée, déployez l'application :

```bash
cd kambriq
ENVIRONMENT=dev ./scripts/deploy-local.sh
```

Ou via GitHub Actions :
- Push sur `develop` → Déploiement automatique
- Workflow Dispatch → Déploiement manuel

---

## 🔍 Vérifications

### Vérifier le déploiement SHARED

```bash
cd kambriq-aws-iac-terraform/envs/shared
terraform output
```

### Vérifier le déploiement DEV-V2

```bash
cd kambriq-aws-iac-terraform/envs/dev-v2
terraform output
```

### Vérifier les ressources AWS

```bash
# VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=kambriq-shared-vpc"

# ECS Cluster
aws ecs describe-clusters --clusters kambriq-dev-cluster

# ECS Services
aws ecs list-services --cluster kambriq-dev-cluster

# RDS
aws rds describe-db-instances --db-instance-identifier kambriq-dev-db

# ECR Repositories
aws ecr describe-repositories --repository-names kambriq-api kambriq-web
```

---

## ⚠️ Points d'Attention

1. **Ordre obligatoire** : SHARED → DEV-V2 (pas l'inverse)
2. **Backend S3** : Le bucket doit exister avant `terraform init`
3. **Remote State** : DEV-V2 lit les outputs de SHARED via `terraform_remote_state`
4. **Secrets SSM** : Doivent être créés après le déploiement de DEV-V2
5. **Certificats ACM** : CloudFront nécessite un certificat en `us-east-1`

---

## 🐛 Troubleshooting

### Erreur : "Backend configuration changed"
```bash
terraform init -reconfigure
```

### Erreur : "Remote state not found"
Vérifiez que SHARED est déployé et que le state file existe dans S3.

### Erreur : "Certificate not found"
Vérifiez que les certificats ACM sont créés et que les ARNs sont corrects.

---

*Dernière mise à jour : 2026-01-03*
