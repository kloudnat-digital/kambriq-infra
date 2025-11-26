# LEGACY: This refactoring plan has been completed.
# The refactoring described here (shared module, remote_state) is already implemented.
# This document is kept for historical reference only.
#
# Terraform Refactoring Plan - KAMBRIQ Infrastructure

## Objectif

Refactoriser la structure Terraform pour introduire une couche **shared** qui mutualise les ressources communes (VPC, DNS, SES, ACM, logs) entre les environnements dev et prod, tout en gardant les ressources spécifiques à chaque environnement (RDS, Lambda, API Gateway, S3 buckets) séparées.

## Structure cible

```
.
├── modules/
│   ├── shared/              # NOUVEAU : Module pour ressources partagées
│   │   ├── main.tf         # VPC, NAT, Route53, SES, ACM, S3 logs
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── network/            # À SUPPRIMER (intégré dans shared)
│   ├── ses/                # À SUPPRIMER (intégré dans shared)
│   ├── rds-postgres/       # GARDER (env-specific)
│   ├── s3-static-site/     # GARDER (env-specific)
│   ├── s3-media/           # GARDER (env-specific)
│   ├── cloudfront/         # GARDER (env-specific)
│   ├── lambda-api/         # GARDER (env-specific)
│   ├── api-gateway/        # GARDER (env-specific)
│   └── iam/                # GARDER (env-specific, mais peut référencer shared)
│
└── envs/
    ├── shared/             # NOUVEAU : Stack shared
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── backend.tf
    │   └── terraform.tfvars.example
    │
    ├── dev/                # MODIFIÉ : Consomme shared via remote_state
    │   ├── main.tf         # Supprime network et ses, utilise remote_state
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── backend.tf
    │   └── terraform.tfvars.example
    │
    └── prod/                # MODIFIÉ : Consomme shared via remote_state
        ├── main.tf          # Supprime network et ses, utilise remote_state
        ├── variables.tf
        ├── outputs.tf
        ├── backend.tf
        └── terraform.tfvars.example
```

## Ressources partagées (modules/shared)

### 1. VPC + Networking
- **VPC dédiée** (remplace la VPC par défaut)
- **Subnets** : 2 public (AZ différentes) + 2 private (AZ différentes)
- **Internet Gateway** pour les subnets publics
- **NAT Gateway** (1 seul, dans une AZ publique pour réduire les coûts)
- **Route tables** pour public et private subnets
- **Security Groups** de base (seront étendus par dev/prod si besoin)

### 2. Route53
- **Hosted Zone** pour `kambriq.com`
- Outputs : zone_id, name_servers

### 3. SES
- **Domain Identity** pour `kambriq.com`
- **Email Identity** pour `noreply@kambriq.com`
- **DKIM** configuration
- Outputs : domain_identity_arn, email_identity_arn, from_email

### 4. ACM (Certificate Manager)
- **Wildcard certificate** pour `*.kambriq.com` (région us-east-1 pour CloudFront)
- **Wildcard certificate** pour `*.kambriq.com` (région eu-central-1 pour API Gateway)
- Outputs : cloudfront_certificate_arn, api_certificate_arn

### 5. S3 Logs & Artifacts
- **S3 bucket** pour CloudWatch logs (si besoin)
- **S3 bucket** pour artifacts/backups partagés
- Outputs : logs_bucket_id, artifacts_bucket_id

### 6. IAM Base Policies (optionnel)
- Policies de base pour CI/CD
- Outputs : ci_cd_role_arn (si créé)

## Ressources par environnement (dev/prod)

### Dev & Prod (séparés)
- **RDS PostgreSQL** : instance dédiée par env
- **Lambda API** : fonction dédiée par env
- **API Gateway** : HTTP API dédiée par env
- **S3 Static Site** : bucket dédié par env
- **S3 Media** : bucket dédié par env
- **CloudFront** : distribution dédiée par env
- **IAM Roles** : rôles Lambda par env

## Flux de déploiement

1. **Déployer shared en premier** :
   ```bash
   cd envs/shared
   terraform init
   terraform plan
   terraform apply
   ```

2. **Déployer dev** :
   ```bash
   cd envs/dev
   terraform init
   terraform plan  # Lit les outputs de shared via remote_state
   terraform apply
   ```

3. **Déployer prod** :
   ```bash
   cd envs/prod
   terraform init
   terraform plan  # Lit les outputs de shared via remote_state
   terraform apply
   ```

## Backend State

- **Shared** : `kloudnat-infra-shared-store/kambriq/shared/terraform.tfstate`
- **Dev** : `kloudnat-infra-shared-store/kambriq/dev/terraform.tfstate`
- **Prod** : `kloudnat-infra-shared-store/kambriq/prod/terraform.tfstate`

## Migration depuis l'existant

### Étapes de migration

1. ✅ Créer `modules/shared` avec toutes les ressources partagées
2. ✅ Créer `envs/shared` qui instancie `modules/shared`
3. ✅ Déployer `envs/shared` (créer VPC, Route53, SES, ACM, etc.)
4. ✅ Modifier `envs/dev` pour utiliser `remote_state` au lieu de `module.network` et `module.ses`
5. ✅ Modifier `envs/prod` pour utiliser `remote_state` au lieu de `module.network` et `module.ses`
6. ✅ Tester `terraform plan` dans dev et prod
7. ✅ Appliquer les changements (migration des ressources existantes)

### Points d'attention

- **VPC** : Actuellement utilise la VPC par défaut. La migration vers une VPC dédiée nécessitera de recréer les ressources (RDS, Lambda) dans la nouvelle VPC. Planifier un downtime ou utiliser un blue/green deployment.
- **SES** : Le domaine est déjà vérifié ? Si oui, Terraform devrait le détecter et l'import. Sinon, il faudra re-vérifier.
- **Route53** : Si le domaine est déjà géré ailleurs, il faudra soit migrer les enregistrements DNS, soit utiliser un data source au lieu de créer une nouvelle hosted zone.

## Avantages

- ✅ **Réduction des coûts** : 1 seul NAT Gateway au lieu de 2 (dev + prod)
- ✅ **Centralisation** : DNS, certificats, SES gérés en un seul endroit
- ✅ **Séparation claire** : shared vs env-specific
- ✅ **Maintenance facilitée** : modifications DNS/certificats en un seul endroit

## Limitations / Simplifications

- Pas de KMS CMK (utilise les clés AWS gérées)
- Pas de staging environment pour l'instant (peut être ajouté plus tard)
- NAT Gateway dans une seule AZ (compromis coût/disponibilité)

