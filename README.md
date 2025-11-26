# KAMBRIQ AWS Infrastructure as Code (Terraform)

Infrastructure Terraform modulaire pour l'application KAMBRIQ sur AWS.

## 📚 Documentation

- **[Guide d'usage Terraform](docs/setup/TERRAFORM_USAGE.md)** - Guide complet pour utiliser ce dépôt
- **[Intégration avec l'application](docs/integration/APP_INTEGRATION.md)** - Comment l'app consomme les outputs Terraform
- **[Résumé du nettoyage](docs/maintenance/CLEANUP_SUMMARY.md)** - Historique du nettoyage du dépôt

## Structure du projet

```
.
├── modules/              # Modules Terraform réutilisables
│   ├── shared/          # Ressources partagées (VPC, Route53, SES, ACM)
│   ├── rds-postgres/    # Base de données PostgreSQL
│   ├── s3-static-site/  # Bucket S3 pour frontend Next.js
│   ├── s3-media/        # Bucket S3 pour médias/documents
│   ├── cloudfront/      # Distribution CloudFront
│   ├── lambda-api/      # Fonction Lambda pour API NestJS
│   ├── api-gateway/     # API Gateway HTTP API
│   └── iam/             # Rôles et policies IAM
├── envs/                # Configurations par environnement
│   ├── shared/          # Stack shared (VPC, DNS, SES, ACM)
│   ├── dev/             # Environnement de développement
│   └── prod/            # Environnement de production
├── docs/                # Documentation organisée par usage
│   ├── setup/           # Guides de démarrage (TERRAFORM_USAGE.md)
│   ├── integration/     # Guides d'intégration (APP_INTEGRATION.md)
│   └── maintenance/     # Documentation de maintenance
├── legacy/              # Modules et fichiers obsolètes (référence uniquement)
│   └── modules/         # Anciens modules (network, ses) - non utilisés
└── versions.tf          # Contraintes de versions
```

## Architecture MVP KAMBRIQ – Serverless AWS

### Vue d'ensemble de l'architecture MVP

Pour le MVP (v1.0.0), l'architecture retenue est **100 % serverless AWS** pour optimiser les coûts et simplifier l'opérationnel :

**Frontend :**
- **S3 + CloudFront** : Next.js en export statique (`output: 'export'`)
  - Bucket S3 pour héberger les fichiers statiques
  - Distribution CloudFront pour la CDN et le HTTPS
  - Pas de serveur à gérer, coûts très faibles

**Backend :**
- **Lambda + API Gateway** : NestJS déployé comme fonction serverless
  - Lambda Node.js 20.x (512MB, 30s timeout)
  - API Gateway HTTP API pour le routage
  - Auto-scaling selon la charge, pay-per-use

**Base de données :**
- **RDS PostgreSQL** : Instance dédiée t4g.micro
  - 20GB gp3 storage
  - Backups automatiques (7j en dev, 30j en prod)
  - Accès via VPC privée depuis Lambda

**Stockage :**
- **S3** : Buckets séparés pour :
  - Frontend statique (public via CloudFront)
  - Médias/documents (privé, accès via API)

**Email :**
- **SES** : Amazon Simple Email Service
  - Domain identity pour `kambriq.com`
  - Email identity pour `noreply@kambriq.com`

**Secrets & Configuration :**
- **SSM Parameter Store / Secrets Manager** : Stockage des secrets
  - Mots de passe de base de données
  - Clés JWT
  - Secrets OAuth
  - **Jamais** dans Git ou Terraform outputs

**Réseau :**
- **VPC** : Réseau privé avec subnets publics/privés
- **NAT Gateway** : 1 seul pour réduire les coûts
- **Route53** : DNS pour `kambriq.com`

> **Note** : Pour le MVP (v1.0.0), l'architecture retenue est 100 % serverless AWS (Lambda + API Gateway + S3 + CloudFront + RDS). Une migration vers ECS/EKS pourra être envisagée plus tard en fonction de la montée en charge et des besoins spécifiques (WebSockets, long-running tasks, etc.).

### Vue d'ensemble des stacks Terraform

L'infrastructure est organisée en **3 stacks Terraform** :

1. **`envs/shared`** : Ressources partagées entre tous les environnements
   - VPC avec public/private subnets + NAT Gateway (1 seul pour réduire les coûts)
   - Route53 hosted zone pour `kambriq.com`
   - SES domain identity
   - ACM certificates (API Gateway)
   - S3 buckets pour logs et artifacts

2. **`envs/dev`** : Environnement de développement
   - RDS PostgreSQL (instance dédiée)
   - Lambda API + API Gateway
   - S3 static site + CloudFront
   - S3 media bucket
   - IAM roles pour Lambda

3. **`envs/prod`** : Environnement de production
   - RDS PostgreSQL (instance dédiée, backups 30 jours)
   - Lambda API + API Gateway
   - S3 static site + CloudFront
   - S3 media bucket
   - IAM roles pour Lambda
   - Domaines personnalisés (app.kambriq.com, api.kambriq.com)

### Flux de déploiement

**IMPORTANT** : Le stack `shared` doit être déployé **EN PREMIER** avant `dev` et `prod`.

```bash
# 1. Déployer shared
cd envs/shared
terraform init
terraform plan
terraform apply

# 2. Déployer dev
cd ../dev
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply

# 3. Déployer prod
cd ../prod
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply
```

### Ressources par stack

#### Stack Shared (`envs/shared`)
- **VPC** : 10.0.0.0/16 avec 2 public subnets + 2 private subnets
- **NAT Gateway** : 1 seul (dans une AZ publique) pour réduire les coûts
- **Route53** : Hosted zone pour `kambriq.com`
- **SES** : Domain identity + email identity (`noreply@kambriq.com`)
- **ACM** : Certificat wildcard `*.kambriq.com` pour API Gateway
- **S3** : Buckets pour logs et artifacts

#### Stack Dev (`envs/dev`)
- **RDS PostgreSQL** : t4g.micro, 20GB gp3, backups 7 jours
- **Lambda API** : Node.js 20.x, 512MB, 30s timeout
- **API Gateway** : HTTP API (URL par défaut ou `api-dev.kambriq.com`)
- **S3 Static** : Bucket pour frontend Next.js
- **S3 Media** : Bucket pour médias/documents
- **CloudFront** : Distribution pour frontend (URL par défaut ou `app-dev.kambriq.com`)

#### Stack Prod (`envs/prod`)
- **RDS PostgreSQL** : t4g.micro, 20GB gp3, backups 30 jours
- **Lambda API** : Node.js 20.x, 512MB, 30s timeout
- **API Gateway** : HTTP API avec domaine personnalisé (`api.kambriq.com`)
- **S3 Static** : Bucket pour frontend Next.js
- **S3 Media** : Bucket pour médias/documents
- **CloudFront** : Distribution avec domaine personnalisé (`app.kambriq.com`)

### Différences entre environnements

| Configuration | Dev | Prod |
|--------------|-----|------|
| Backup retention | 7 jours | 30 jours |
| Final snapshot | Non (skip_final_snapshot = true) | Oui (skip_final_snapshot = false) |
| Domaines personnalisés | Optionnel | Recommandé (app.kambriq.com, api.kambriq.com) |

## Déploiement

### Prérequis

1. Installer Terraform (>= 1.5.0)
2. Configurer les credentials AWS (via `aws configure` ou variables d'environnement)
3. Le backend S3 est configuré : `kloudnat-infra-shared-store` dans `eu-central-1`

## CI/CD

### Workflows GitHub Actions

Trois workflows GitHub Actions gèrent le déploiement de l'infrastructure :

#### Vue d'ensemble

Les workflows Terraform sont configurés pour :
- **Développement** : Déploiement automatique sur push vers `develop`
- **Production** : Déploiement manuel ou via tags pour sécurité maximale
- **Validation** : Format check, validation, et plan avant chaque apply

### Workflows Terraform

#### 1. Workflow `terraform-dev.yml` - Environnement de développement

Gère le stack `dev` avec déploiement automatique.

**Triggers :**
- **Push vers `develop`** : Exécute `terraform fmt`, `validate`, `plan` et `apply` automatiquement
- **Workflow Dispatch** : Déclenchement manuel possible

**Comportement :**
- Format check et validation avant chaque plan
- Plan généré et sauvegardé
- Apply automatique avec `-auto-approve` pour accélérer le développement
- Outputs non-sensibles affichés dans le résumé GitHub Actions

**Secrets requis :**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (optionnel, défaut: `eu-central-1`)

**Note** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** passés via GitHub Secrets. Ils sont gérés via SSM Parameter Store / Secrets Manager et configurés directement dans les variables d'environnement Lambda.

#### 2. Workflow `terraform-prod.yml` - Environnement de production

Gère le stack `prod` avec sécurité renforcée.

**Triggers :**
- **Workflow Dispatch** : Déclenchement manuel avec choix `plan` ou `apply`
- **Push vers tags `v*`** : Déclenchement automatique sur version tags (plan + apply)

**Comportement :**
- **Job 1 (terraform-plan)** : Toujours exécuté, génère un plan et l'upload comme artifact
- **Job 2 (terraform-apply)** : Exécuté uniquement si :
  - Workflow dispatch avec `action = apply`
  - Push vers un tag `v*`
- Plan sauvegardé comme artifact pour review
- Protection via GitHub Environments (décommenter pour activer l'approbation manuelle)

**Secrets requis :**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (optionnel, défaut: `eu-central-1`)

**Note** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** passés via GitHub Secrets. Ils sont gérés via SSM Parameter Store / Secrets Manager et configurés directement dans les variables d'environnement Lambda.

> **⚠️ Sécurité** : Le workflow prod nécessite une action explicite pour appliquer les changements. Toujours revoir le plan avant d'appliquer en production.

#### 3. Workflow `terraform-shared.yml` - Infrastructure partagée

Gère le stack `shared` (VPC, Route53, SES, ACM, S3 logs).

**Triggers :**
- **Pull Request vers `main`** : Exécute `terraform fmt`, `validate` et `plan`
- **Push vers `main`** : Exécute `terraform fmt`, `validate`, `plan` et `apply`

**Comportement :**
- Plan automatique sur les PRs (commentaire sur la PR)
- Apply automatique sur push vers main (si fichiers modifiés dans `envs/shared/` ou `modules/`)

**Pour lancer un apply en production :**

1. Aller dans l'onglet "Actions" du repository
2. Sélectionner "Terraform - Prod Environment"
3. Cliquer sur "Run workflow"
4. Choisir `action = apply` dans le menu déroulant
5. Cliquer sur "Run workflow"

⚠️ **Note** : Pour la production, il est recommandé d'activer l'approbation manuelle dans GitHub (Settings → Environments → production) en décommentant la ligne `environment: production` dans le workflow.

### Intégration avec le repo applicatif

Les workflows Terraform génèrent des outputs qui sont consommés par les workflows de déploiement applicatif dans le repo `kambriq` :

- **`deploy-dev.yml`** : Utilise les outputs Terraform pour configurer les builds
- **`deploy-prod.yml`** : (À créer) Même principe pour la production

Voir [`docs/integration/APP_INTEGRATION.md`](docs/integration/APP_INTEGRATION.md) pour les détails sur l'intégration. Voir aussi [`docs/setup/TERRAFORM_USAGE.md`](docs/setup/TERRAFORM_USAGE.md) pour un guide d'usage complet.

#### Configuration des secrets GitHub

Configurer les secrets suivants dans GitHub (Settings → Secrets and variables → Actions) :

**Option 1 : OIDC avec IAM Role (Recommandé)**
- `AWS_ROLE_ARN` : ARN du rôle IAM (ex: `arn:aws:iam::ACCOUNT_ID:role/github-actions-role`)
- `AWS_REGION` : `eu-central-1`

**Option 2 : Credentials statiques**
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS
- `AWS_REGION` : `eu-central-1`

**⚠️ Important** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** stockés dans GitHub Secrets. Ils sont gérés via :
- **SSM Parameter Store** ou **AWS Secrets Manager** pour les secrets de production
- **Variables d'environnement Lambda** configurées directement (pas via Terraform variables)
- Les workflows Terraform ne gèrent que l'infrastructure, pas les secrets applicatifs

**⚠️ Bonnes pratiques de sécurité :**
- Les secrets applicatifs (DB password, JWT secrets) sont stockés dans SSM Parameter Store / Secrets Manager
- Ne jamais réutiliser les mêmes secrets entre dev et prod
- Utiliser des mots de passe forts et uniques pour chaque environnement
- Générer des JWT_SECRET d'au moins 32 caractères
- Les workflows Terraform ne manipulent pas les secrets applicatifs, uniquement l'infrastructure

**Configuration OIDC :**
1. Créer un OIDC provider dans AWS IAM (si pas déjà fait)
2. Créer un rôle IAM avec trust policy permettant GitHub Actions
3. Attacher les policies nécessaires au rôle (S3, Terraform state, etc.)
4. Configurer `AWS_ROLE_ARN` dans les secrets GitHub
5. Décommenter la section OIDC dans les workflows et commenter la section static credentials

**Note** : Actuellement, les workflows sont configurés pour utiliser l'**Option 2 (Credentials statiques)** par défaut. Pour passer à OIDC, suivez les instructions dans chaque workflow.

### Déploiement local

#### 1. Stack Shared (à déployer EN PREMIER)

```bash
# 1. Se placer dans le répertoire shared
cd envs/shared

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars si nécessaire (les valeurs par défaut sont généralement correctes)

# 4. Initialiser Terraform
terraform init

# 5. Vérifier le plan d'exécution
terraform plan

# 6. Appliquer les changements
terraform apply
```

#### 2. Stack Dev

```bash
# 1. Se placer dans le répertoire dev
cd envs/dev

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars avec vos valeurs réelles
#    - Remplacer CHANGE_ME_STRONG_PASSWORD par un mot de passe fort
#    - Remplacer CHANGE_ME_JWT_SECRET_KEY par une clé secrète JWT
#    Utiliser un gestionnaire de secrets (Vault, LastPass, 1Password, etc.)
#    ⚠️  Ne jamais commiter terraform.tfvars dans Git

# 4. Initialiser Terraform (télécharge les providers et configure le backend S3)
terraform init

# 5. Vérifier le plan d'exécution (optionnel mais recommandé)
terraform plan

# 6. Appliquer les changements
terraform apply
```

#### 3. Stack Prod

```bash
# 1. Se placer dans le répertoire prod
cd envs/prod

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars avec vos valeurs réelles
#    - ⚠️  EN PRODUCTION : Utiliser OBLIGATOIREMENT un gestionnaire de secrets
#      (AWS Secrets Manager, HashiCorp Vault, etc.)
#    - Remplacer CHANGE_ME_STRONG_PASSWORD par un mot de passe fort
#    - Remplacer CHANGE_ME_JWT_SECRET_KEY par une clé secrète JWT
#    - Optionnel : Configurer les domaines personnalisés (cloudfront_domain, api_domain)
#    ⚠️  Ne jamais commiter terraform.tfvars dans Git

# 4. Initialiser Terraform
terraform init

# 5. Vérifier le plan d'exécution (OBLIGATOIRE en production)
terraform plan

# 6. Appliquer les changements
#    ⚠️  En production, le déploiement se fait principalement via GitHub Actions
#    pour garantir la traçabilité et la sécurité
terraform apply
```

**Note** : Les fichiers `terraform.tfvars` sont ignorés par git (`.gitignore`) pour des raisons de sécurité. Ils contiennent des secrets et ne doivent jamais être commités.

## Outputs Terraform

Les outputs Terraform fournissent les informations nécessaires pour configurer l'application. Pour les consulter :

```bash
cd envs/dev  # ou envs/prod
terraform output
```

**📚 Documentation complète** : Voir [`docs/integration/APP_INTEGRATION.md`](docs/integration/APP_INTEGRATION.md) pour :
- Le mapping complet entre outputs Terraform et variables d'environnement de l'application
- Comment intégrer les outputs dans les pipelines CI/CD
- La gestion des secrets via SSM Parameter Store

### Outputs disponibles

#### Stack Shared (`envs/shared`)

**VPC & Networking :**
- `vpc_id` : ID de la VPC
- `vpc_cidr` : CIDR block de la VPC
- `public_subnet_ids` : Liste des IDs des subnets publics
- `private_subnet_ids` : Liste des IDs des subnets privés
- `all_subnet_ids` : Liste de tous les subnets (public + private)
- `nat_gateway_id` : ID du NAT Gateway

**Route53 :**
- `route53_zone_id` : ID de la hosted zone
- `route53_zone_name` : Nom de la hosted zone
- `route53_name_servers` : Serveurs DNS (à configurer dans le registrar)

**SES :**
- `ses_domain_identity_arn` : ARN de l'identité domaine SES
- `ses_email_identity_arn` : ARN de l'identité email SES
- `ses_from_email` : Adresse email par défaut
- `ses_domain_verification_token` : Token de vérification DNS

**ACM :**
- `api_certificate_arn` : ARN du certificat pour API Gateway

**S3 :**
- `logs_bucket_id` : ID du bucket S3 pour logs
- `artifacts_bucket_id` : ID du bucket S3 pour artifacts

#### Stack Dev/Prod (`envs/dev` et `envs/prod`)

**AWS Region :**
- `region` : Région AWS (ex: `eu-central-1`)

**Frontend :**
- `frontend_cloudfront_domain` : Nom de domaine CloudFront
- `frontend_s3_bucket_name` : Nom du bucket S3 pour le frontend statique

**Media S3 :**
- `media_s3_public_bucket_name` : Nom du bucket S3 pour les médias publics
- `media_s3_private_bucket_name` : Nom du bucket S3 pour les médias privés
- **Note** : Actuellement, les deux référencent le même bucket

**API Gateway :**
- `api_gateway_base_url` : URL complète de l'API Gateway (https://...)

**Base de données :**
- `rds_endpoint` : Endpoint complet RDS (host:port)
- `rds_db_name` : Nom de la base de données
- `rds_username` : Nom d'utilisateur de la base de données (**sensible**)

**SES :**
- `ses_domain_identity_arn` : ARN de l'identité domaine SES (depuis shared)
- `ses_from_email` : Adresse email par défaut pour l'envoi (depuis shared)

**Lambda :**
- `lambda_function_name` : Nom de la fonction Lambda
- `cloudfront_distribution_id` : ID de la distribution CloudFront (pour invalidation de cache)

### Utilisation dans le repo applicatif

Ces outputs peuvent être récupérés via `terraform output -json` et utilisés pour configurer l'application :

```bash
# Exporter les outputs en JSON
terraform output -json > terraform-outputs.json

# Ou récupérer une valeur spécifique
terraform output -raw api_url
terraform output -raw db_endpoint
```

## Backend Terraform (État)

L'état Terraform est stocké dans S3 : `kloudnat-infra-shared-store`

- **Shared** : `kambriq/shared/terraform.tfstate`
- **Dev** : `kambriq/dev/terraform.tfstate`
- **Prod** : `kambriq/prod/terraform.tfstate`

Région : `eu-central-1`

La configuration est déjà définie dans `envs/*/backend.tf`.

**Important** : Les stacks `dev` et `prod` consomment les outputs du stack `shared` via `terraform_remote_state`. Assurez-vous que le stack `shared` est déployé et que son état est accessible avant de déployer `dev` ou `prod`.

## TODO

- [x] Migrer l'état Terraform vers S3 backend
- [x] Créer une structure shared/dev/prod avec remote_state
- [x] Créer des workflows GitHub Actions séparés par stack
- [x] Séparer les secrets entre dev et prod
- [x] Créer les workflows de déploiement applicatif (deploy-dev.yml)
- [ ] Ajouter des alarmes CloudWatch pour monitoring
- [ ] Configurer des backups automatiques pour RDS (déjà configuré : 7j dev, 30j prod)
- [ ] Migrer les secrets vers AWS Secrets Manager (actuellement SSM Parameter Store)
- [ ] Configurer des domaines personnalisés pour CloudFront et API Gateway (prod) - optionnel
- [ ] Ajouter des règles de sécurité supplémentaires (WAF, etc.)
- [ ] Optimiser les coûts avec Reserved Instances ou Savings Plans (si applicable)
- [ ] Ajouter un certificat ACM pour CloudFront dans us-east-1 (si domaine personnalisé nécessaire)

> **Note** : Pour le MVP (v1.0.0), l'architecture retenue est 100 % serverless AWS (Lambda + API Gateway + S3 + CloudFront + RDS). Une migration vers ECS/EKS pourra être envisagée plus tard en fonction de la montée en charge et des besoins spécifiques (WebSockets, long-running tasks, etc.).

## Coûts estimés (MVP)

- RDS t4g.micro: ~$15-20/mois
- Lambda: Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- API Gateway: Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- S3: ~$0.023/Go/mois
- CloudFront: Pay-per-use (gratuit jusqu'à 1To/mois)
- SES: Gratuit jusqu'à 62,000 emails/mois

Total estimé MVP: ~$20-30/mois (hors trafic)

## Architecture technique

### Remote State

Les stacks `dev` et `prod` consomment les outputs du stack `shared` via `terraform_remote_state` :

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/shared/terraform.tfstate"
    region = "eu-central-1"
  }
}
```

Cela permet de :
- Réutiliser la VPC, Route53, SES créés dans `shared`
- Éviter la duplication de ressources
- Maintenir une séparation claire entre ressources partagées et spécifiques

### Workflows GitHub Actions

Le repository utilise **3 workflows séparés** pour une meilleure organisation :

1. **`terraform-shared.yml`** : Gère uniquement le stack shared
2. **`terraform-dev.yml`** : Gère uniquement le stack dev
3. **`terraform-prod.yml`** : Gère uniquement le stack prod (déclenchement manuel)

Chaque workflow :
- Vérifie le format avec `terraform fmt -check`
- Valide la configuration avec `terraform validate`
- Génère un plan avec `terraform plan`
- Applique les changements (selon les conditions définies)
- Commente automatiquement les PRs avec le plan Terraform
- Sauvegarde les outputs comme artifacts

## Notes importantes

- **Gestion des secrets** : Les secrets applicatifs (DB password, JWT secrets) sont gérés via SSM Parameter Store / Secrets Manager, **pas** via GitHub Secrets ou Terraform variables. Les workflows Terraform ne manipulent que l'infrastructure.
- **Stack shared en premier** : Le stack `shared` doit être déployé avant `dev` et `prod` car ces derniers dépendent de ses outputs.
- **VPC dédiée** : Une VPC dédiée est créée dans le stack `shared` (plus de VPC par défaut).
- **NAT Gateway unique** : Un seul NAT Gateway est créé pour réduire les coûts (dans une AZ publique).
- **Documentation organisée** : La documentation est organisée par usage dans `docs/setup/`, `docs/integration/`, et `docs/maintenance/`.
- **Modules legacy** : Les anciens modules (`network`, `ses`) ont été déplacés dans `legacy/` et ne sont plus utilisés.
- **Coûts** : Les ressources sont configurées pour minimiser les coûts tout en restant fonctionnelles.

