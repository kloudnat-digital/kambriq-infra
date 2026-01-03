# Analyse Structure Terraform

## Structure des Stacks

### 1. Stack `shared/`
- **Rôle** : Infrastructure partagée entre dev et prod
- **Ressources** : VPC, Subnets, NAT Gateway, Route53, SES, ACM, S3
- **Backend** : S3 (`kloudnat-infra-shared-store`, key: `kambriq/shared/terraform.tfstate`)
- **Dépendances** : Aucune (stack indépendant)

### 2. Stack `dev-v2/`
- **Rôle** : Infrastructure spécifique dev
- **Ressources** : ECS, ALB, CloudFront, RDS, ECR, IAM
- **Backend** : S3 (`kloudnat-infra-shared-store`, key: `kambriq/dev-v2/terraform.tfstate`)
- **Dépendances** : **OUI** - Utilise `terraform_remote_state` pour lire les outputs de `shared`

### 3. Stack `prod/` (V1 - à migrer)
- **Rôle** : Infrastructure prod (V1)
- **Dépendances** : Shared

## Ordre de Déploiement

**OBLIGATOIRE** : `shared` → `dev-v2` → `prod-v2` (quand migré)

**Raison** : `dev-v2` et `prod` consomment les outputs de `shared` via `terraform_remote_state`
