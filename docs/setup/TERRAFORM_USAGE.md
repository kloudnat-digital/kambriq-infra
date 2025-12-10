# Guide d'usage Terraform – KAMBRIQ

Ce guide explique comment utiliser le dépôt Terraform pour déployer l'infrastructure AWS de KAMBRIQ.

## 1. Objectif du repo

Ce dépôt gère l'infrastructure AWS pour la plateforme KAMBRIQ via Terraform (Infrastructure as Code).

**Infrastructure partagée** (stack `shared`) :
- VPC avec subnets publics/privés
- Route53 (DNS pour `kambriq.com`)
- SES (Simple Email Service) - identités domaine et email
- ACM (certificats SSL pour API Gateway)

**Infrastructure applicative** (stacks `dev` et `prod`) :
- RDS PostgreSQL (base de données)
- Lambda (API NestJS avec handler `dist/lambda.handler`)
- API Gateway (point d'entrée HTTP API)
- Frontend OpenNext (S3 assets + CloudFront + Lambda SSR)
- S3 (buckets pour médias et artefacts de build)
- IAM (rôles et politiques)

## 2. Structure du repo

```
kambriq-aws-iac-terraform/
├── modules/              # Modules Terraform réutilisables
│   ├── shared/          # Ressources partagées (VPC, Route53, SES, ACM)
│   ├── rds-postgres/    # Base de données PostgreSQL
│   ├── frontend/        # Frontend OpenNext (S3 + CloudFront + Lambda SSR) ⭐
│   ├── s3-media/        # Bucket S3 pour médias/documents
│   ├── lambda-api/      # Fonction Lambda pour API NestJS (handler: dist/lambda.handler)
│   ├── api-gateway/     # API Gateway HTTP API
│   ├── iam/             # Rôles et policies IAM
│   ├── s3-static-site/  # ⚠️ LEGACY - Remplacé par modules/frontend/
│   └── cloudfront/      # ⚠️ LEGACY - Remplacé par modules/frontend/
├── envs/                # Configurations par environnement
│   ├── shared/          # Stack shared (VPC, DNS, SES, ACM)
│   ├── dev/             # Environnement de développement
│   └── prod/            # Environnement de production
└── .github/workflows/   # Workflows GitHub Actions
    ├── terraform-shared.yml  # Déploiement infrastructure partagée
    ├── terraform-dev.yml     # Déploiement infrastructure dev
    └── terraform-prod.yml    # Déploiement infrastructure prod
```

### Workflows GitHub Actions

- **`terraform-shared.yml`** : Gère l'infrastructure partagée (VPC, Route53, SES, ACM)
  - Sur PR : exécute `terraform plan` et commente la PR
  - Sur push vers `main` : exécute `terraform plan` + `apply`

- **`terraform-dev.yml`** : Gère l'infrastructure dev (RDS, Lambda, API Gateway, S3, CloudFront)
  - CloudFront alias `dev.kambriq.com` géré par Terraform via `envs/dev/variables.tf`
  - **⚠️ Important** : Gère uniquement l'infrastructure, ne déploie pas le code applicatif
  - Déclenchement : Pull Request vers `develop` (plan uniquement), Push sur `develop` (plan + apply), Workflow Dispatch (plan uniquement)
  - Exécute `terraform plan` + `apply` (sur push `develop`) pour créer/modifier les ressources AWS
  - Le code applicatif est déployé via `deploy-app-dev.yml` dans le repository `kambriq`

- **`terraform-prod.yml`** : Gère l'infrastructure prod (même ressources que dev)
  - **⚠️ Important** : Gère uniquement l'infrastructure, ne déploie pas le code applicatif
  - CloudFront alias `kambriq.com` géré par Terraform via `envs/prod/variables.tf`
  - Déclenchement manuel (`workflow_dispatch`) uniquement
  - Protection via GitHub Environment `production` (approbation manuelle possible)
  - Le code applicatif est déployé via `deploy-app-prod.yml` dans le repository `kambriq`

## 3. Ordre de lecture des docs existants

Pour comprendre l'infrastructure, lisez dans cet ordre :

1. **`README.md`** (racine) : Vue d'ensemble de l'architecture, structure des stacks, différences dev/prod
2. **`modules/`** : Documentation des modules réutilisables (chaque module a ses propres fichiers `.tf`)
3. **`envs/shared/`** : Configuration de l'infrastructure partagée
4. **`envs/dev/`** : Configuration de l'environnement de développement
5. **`envs/prod/`** : Configuration de l'environnement de production

> **Note** : Si des README spécifiques existent dans `envs/shared/`, `envs/dev/`, ou `envs/prod/`, consultez-les pour des détails spécifiques à chaque environnement.

## 4. Déployer l'infra shared (VPC, Route53, SES, ACM)

L'infrastructure partagée doit être déployée **EN PREMIER** avant les environnements dev et prod.

### Déploiement local

1. **Cloner le repo** :
   ```bash
   git clone <repo-url>
   cd kambriq-aws-iac-terraform
   ```

2. **Vérifier la configuration du backend Terraform** :
   - Le backend S3 est configuré dans `envs/shared/backend.tf`
   - Bucket : `kloudnat-infra-shared-store`
   - Région : `eu-central-1`
   - State file : `kambriq/shared/terraform.tfstate`

3. **Configurer les credentials AWS** :
   ```bash
   # Option 1 : AWS CLI profile
   export AWS_PROFILE=your-profile
   
   # Option 2 : Variables d'environnement
   export AWS_ACCESS_KEY_ID=your-key
   export AWS_SECRET_ACCESS_KEY=your-secret
   export AWS_DEFAULT_REGION=eu-central-1
   ```

4. **Déployer l'infrastructure shared** :
   ```bash
   cd envs/shared
   terraform init
   terraform plan
   terraform apply
   ```

5. **⚠️ IMPORTANT : Configurer les nameservers Route53** :
   - Après le déploiement, récupérez les nameservers Route53 :
     ```bash
     terraform output route53_name_servers
     ```
   - Configurez ces nameservers dans votre registraire de domaine (GoDaddy, Namecheap, OVH, etc.)
   - **Sans cette étape, les validations SES et ACM échoueront avec des timeouts**
   - Voir le guide détaillé : [ROUTE53_DNS_SETUP.md](./ROUTE53_DNS_SETUP.md)

6. **⚠️ IMPORTANT : Créer manuellement les certificats ACM et identités SES** :
   - **Les certificats ACM et identités SES ne sont plus créés automatiquement par Terraform**
   - Ils doivent être créés et validés manuellement dans la console AWS
   - Après création, récupérez les ARNs et ajoutez-les dans les fichiers `terraform.tfvars`
   - Voir le guide détaillé : [ACM_SES_MANUAL_SETUP.md](./ACM_SES_MANUAL_SETUP.md)
   - **Voir la section 11 ci-dessous** pour la mise à jour des tfvars après création des certificats

### Déploiement via GitHub Actions

1. **Créer une Pull Request** vers `main` :
   - Le workflow `terraform-shared.yml` s'exécute automatiquement
   - Il fait un `terraform plan` et commente la PR avec les résultats

2. **Merger la PR** (push vers `main`) :
   - Le workflow `terraform-shared.yml` s'exécute automatiquement
   - Il fait un `terraform plan` + `apply` si des fichiers dans `envs/shared/` ou `modules/` ont changé

## 5. Déployer l'infra de dev (app KAMBRIQ)

Une fois l'infrastructure shared déployée, vous pouvez déployer l'infrastructure dev.

### Déploiement local

1. **Se positionner dans le répertoire dev** :
   ```bash
   cd envs/dev
   ```

2. **Initialiser Terraform** :
   ```bash
   terraform init
   ```
   Terraform lit automatiquement les outputs de `shared` via `data.terraform_remote_state.shared`.

3. **Planifier les changements** :
   ```bash
   terraform plan
   ```

4. **Appliquer les changements** :
   ```bash
   terraform apply
   ```

### Déploiement via GitHub Actions

1. **Pull Request vers `develop`** :
   - Le workflow `terraform-dev.yml` s'exécute automatiquement
   - Il fait un `terraform plan` uniquement (pas d'apply)
   - Le plan est affiché dans les commentaires de la PR

2. **Push vers `develop`** :
   - Le workflow `terraform-dev.yml` s'exécute automatiquement
   - Il fait un `terraform plan` + `apply` automatiquement (auto-approve)
   - Le plan est sauvegardé comme artifact

3. **Workflow Dispatch (manuel)** :
   - Aller dans Actions → "Terraform Dev (infra only)"
   - Cliquer "Run workflow"
   - Choisir la branche
   - Il fait un `terraform plan` uniquement (pas d'apply automatique)

4. **Vérifier les outputs** :
   - Les outputs non-sensibles sont affichés dans le résumé GitHub Actions
   - Pour voir tous les outputs : `terraform output` (localement) ou `terraform output -json` (dans le workflow)

**⚠️ Note** : Le workflow Terraform ne déploie pas le code applicatif. Pour déployer le code API + Web, utiliser les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`.

### ⚠️ Important : Gestion des secrets

**Les secrets applicatifs (mot de passe DB, JWT secrets) ne sont PAS gérés via Terraform** :

- ❌ Ne pas passer `DB_PASSWORD_DEV` ou `JWT_SECRET_DEV` comme variables Terraform (`TF_VAR_*`)
- ❌ Ne pas stocker ces valeurs dans `terraform.tfvars` (ce fichier est ignoré par Git)
- ❌ Ne pas stocker les secrets dans GitHub Secrets (seulement les credentials techniques CI/CD)
- ✅ Stocker les secrets dans **AWS SSM Parameter Store** avec la structure : `/kambriq/{env}/{api|web}/{parameter_name}`
- ✅ L'application lit les secrets depuis SSM au runtime (voir `api/src/infrastructure/config/config-loader.ts`)
- ✅ Utiliser la convention de nommage : `/kambriq/{dev|prod}/api/DATABASE_URL`, `/kambriq/{dev|prod}/api/JWT_SECRET`, etc.

**Structure SSM recommandée :**
- `/kambriq/dev/api/DATABASE_URL` - URL de connexion PostgreSQL complète
- `/kambriq/dev/api/JWT_SECRET` - Clé secrète JWT
- `/kambriq/dev/api/FRONTEND_URL` - URL du frontend (pour CORS et emails)
- `/kambriq/dev/api/SES_FROM_EMAIL` - Email expéditeur SES
- Même structure pour `/kambriq/prod/api/...`

Terraform ne gère que les ressources d'infrastructure, pas les secrets applicatifs. Les secrets sont lus au runtime par l'application depuis SSM.

## 6. Déployer l'infra de prod (app KAMBRIQ)

L'infrastructure prod suit le même principe que dev, mais avec des garde-fous supplémentaires.

### Déploiement local

1. **Se positionner dans le répertoire prod** :
   ```bash
   cd envs/prod
   ```

2. **Initialiser Terraform** :
   ```bash
   terraform init
   ```

3. **Planifier les changements** :
   ```bash
   terraform plan -out=tfplan
   ```

4. **Réviser le plan** attentivement avant d'appliquer

5. **Appliquer les changements** :
   ```bash
   terraform apply tfplan
   ```

### Déploiement via GitHub Actions

1. **Déclenchement manuel** (`workflow_dispatch`) :
   - Aller dans l'onglet "Actions" du repository
   - Sélectionner "Terraform Prod (infra only)"
   - Cliquer sur "Run workflow"
   - Choisir la branche
   - ⚠️ Approbation manuelle requise (si configurée dans GitHub Environment `production`)
   - Le workflow fait un `terraform plan` puis `apply` automatiquement
   - Le plan est sauvegardé comme artifact (rétention 30 jours)

**⚠️ Note** : Le workflow Terraform ne déploie pas le code applicatif. Pour déployer le code API + Web, utiliser le workflow `deploy-app-prod.yml` dans le repository `kambriq`.

### ⚠️ Sécurité production

- **Toujours réviser le plan** avant d'appliquer en production
- **Ne jamais mettre de secrets applicatifs** dans les `terraform.tfvars` ou comme variables Terraform
- **Utiliser GitHub Environments** avec approbation manuelle (décommenter dans le workflow si nécessaire)
- **Vérifier les outputs** après chaque déploiement

## 7. Relation avec le repo applicatif (kambriq)

**⚠️ Important** : Ce dépôt Terraform gère **uniquement l'infrastructure** (création/modification des ressources AWS). Le code applicatif est dans le dépôt `kambriq` et est déployé via les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml`.

### Séparation des Responsabilités

**Repository `kambriq-aws-iac-terraform` (ce repo) :**
- Gère l'infrastructure via Terraform
- Crée et configure les ressources AWS (Lambda functions, API Gateway, RDS, S3, CloudFront, SSM structure, IAM, VPC, etc.)
- Ne déploie **pas** le code applicatif

**Repository `kambriq` :**
- Gère le code applicatif (API + Web)
- Déploie le code via les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml`
- Effectue directement : build, package, `aws lambda update-function-code`, sync S3, invalidation CloudFront

### Flux de Déploiement

1. **Déployer l'infrastructure** (ce repo) :
   - Déployer `shared` → `dev` → `prod` (dans cet ordre)
   - Terraform crée les ressources AWS (Lambda functions, API Gateway, RDS, S3, CloudFront, etc.)
   - Terraform génère des outputs (S3 bucket, CloudFront domain, API Gateway URL, Lambda function names)

2. **Déployer l'application** (repo `kambriq`) :
   - Les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` :
     - Build API + Web
     - Package en ZIP
     - `aws lambda update-function-code` (API + SSR) - utilise les noms de fonctions depuis les secrets GitHub
     - Sync assets S3 - utilise le nom du bucket depuis les secrets GitHub
     - Invalidation CloudFront - utilise l'ID de distribution depuis les secrets GitHub

### Secrets GitHub pour les Workflows Applicatifs

Les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` nécessitent les secrets suivants (dans le repository `kambriq`) :

| Secret | Description | Source |
|--------|-------------|--------|
| `API_LAMBDA_NAME_DEV` / `API_LAMBDA_NAME_PROD` | Nom de la fonction Lambda API | Terraform output `lambda_function_name` |
| `WEB_SSR_LAMBDA_NAME_DEV` / `WEB_SSR_LAMBDA_NAME_PROD` | Nom de la fonction Lambda SSR | Terraform output (ou nom conventionnel) |
| `WEB_ASSETS_BUCKET_DEV` / `WEB_ASSETS_BUCKET_PROD` | Bucket S3 pour assets statiques | Terraform output |
| `CLOUDFRONT_DISTRIBUTION_ID_DEV` / `CLOUDFRONT_DISTRIBUTION_ID_PROD` | ID de la distribution CloudFront | Terraform output |

**Note** : Les secrets applicatifs (DB password, JWT secrets) ne sont PAS dans les outputs Terraform ni dans GitHub Secrets. Ils sont stockés dans SSM Parameter Store (`/kambriq/{env}/api/...`) et lus au runtime par l'application.

## 8. Commandes utiles

### Voir les outputs Terraform

```bash
# Tous les outputs (format texte)
terraform output

# Outputs en JSON
terraform output -json

# Un output spécifique
terraform output -raw frontend_cloudfront_domain
```

### Vérifier l'état

```bash
# État actuel
terraform state list

# Détails d'une ressource
terraform state show aws_s3_bucket.frontend
```

### Formater et valider

```bash
# Formater les fichiers
terraform fmt -recursive

# Valider la configuration
terraform validate
```

## 9. Dépannage

### Erreur : "Error loading state"

- Vérifier que le backend S3 est correctement configuré
- Vérifier les credentials AWS
- Vérifier que le bucket `kloudnat-infra-shared-store` existe

### Erreur : "Remote state data source not found"

- Vérifier que l'infrastructure `shared` a été déployée avant `dev` ou `prod`
- Vérifier que le state file `kambriq/shared/terraform.tfstate` existe dans S3

### Erreur : "Invalid credentials"

- Vérifier les variables d'environnement AWS ou le profile AWS
- Vérifier les GitHub Secrets si vous utilisez GitHub Actions

## 10. Mise à jour des tfvars après création des certificats ACM

### Contexte

Les certificats ACM pour CloudFront sont créés **manuellement** dans la console AWS en région **us-east-1** (obligatoire pour CloudFront). Une fois créés et validés, leurs ARNs doivent être ajoutés dans les fichiers `terraform.tfvars` avant le premier `terraform apply`.

### Étapes

#### 1. Créer les certificats ACM en us-east-1

Suivez le guide [ACM_SES_MANUAL_SETUP.md](./ACM_SES_MANUAL_SETUP.md) pour créer les certificats :
- **DEV** : Certificat pour CloudFront dev (ex: `*.dev.kambriq.com` ou `app-dev.kambriq.com`)
- **PROD** : Certificat pour CloudFront prod (ex: `*.kambriq.com` ou `app.kambriq.com`)

**⚠️ IMPORTANT** : Les certificats CloudFront **DOIVENT** être créés en région **us-east-1**, même si votre infrastructure est dans **eu-central-1**.

#### 2. Récupérer les ARNs des certificats

Une fois les certificats validés (statut = "Issued"), récupérez leurs ARNs :

**Via la console AWS** :
- Console AWS → Certificate Manager → Région **us-east-1**
- Sélectionnez le certificat → Copiez l'ARN

**Via AWS CLI** :
```bash
# Lister les certificats en us-east-1
aws acm list-certificates --region us-east-1

# Détails d'un certificat (pour obtenir l'ARN complet)
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID" \
  --region us-east-1 \
  --query 'Certificate.CertificateArn' \
  --output text
```

#### 3. Mettre à jour les fichiers tfvars

##### Pour DEV (`envs/dev/terraform.tfvars`)

Décommenter et remplir la variable `cloudfront_certificate_arn` :

```hcl
# ============================================================================
# Domaines personnalisés (optionnel pour DEV)
# ============================================================================

# cloudfront_domain          = "app-dev.kambriq.com"
# Certificat ACM CloudFront créé manuellement en us-east-1
# Voir docs/setup/SES_AND_ACM_MANUAL_SETUP.md pour les instructions
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"
```

**Exemple avec ARN réel** :
```hcl
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f"
```

##### Pour PROD (`envs/prod/terraform.tfvars`)

Décommenter et remplir la variable `cloudfront_certificate_arn` :

```hcl
# ============================================================================
# Domaines personnalisés (recommandé pour PROD)
# ============================================================================

# cloudfront_domain          = "app.kambriq.com"
# Certificat ACM CloudFront créé manuellement en us-east-1
# Voir docs/setup/SES_AND_ACM_MANUAL_SETUP.md pour les instructions
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"
```

**Exemple avec ARN réel** :
```hcl
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:051551940370:certificate/78e0e011-48de-4cc5-835c-9f51304f2292"
```

#### 4. Vérifier la configuration

Avant de lancer `terraform apply`, vérifiez que les ARNs sont corrects :

```bash
# Pour DEV
cd envs/dev
terraform init
terraform validate
terraform plan  # Vérifier que le certificat est bien référencé

# Pour PROD
cd envs/prod
terraform init
terraform validate
terraform plan  # Vérifier que le certificat est bien référencé
```

#### 5. Déployer

Une fois les ARNs configurés dans les tfvars, vous pouvez déployer :

```bash
# Pour DEV
cd envs/dev
terraform apply

# Pour PROD
cd envs/prod
terraform apply
```

### Notes importantes

- ⚠️ **Les certificats doivent être validés** (statut = "Issued") avant d'être utilisés par Terraform
- ⚠️ **Les certificats CloudFront DOIVENT être en us-east-1** (même si l'infrastructure est en eu-central-1)
- ✅ **Les fichiers `terraform.tfvars` ne sont jamais commités** dans Git (déjà dans `.gitignore`)
- 📝 **Documenter les ARNs** dans un gestionnaire de secrets pour référence future
- 🔄 **Si vous créez de nouveaux certificats**, mettez à jour les tfvars avant chaque `terraform apply`

### Dépannage

#### Erreur : "Certificate not found"

- Vérifiez que l'ARN est correct et complet
- Vérifiez que le certificat existe en région **us-east-1**
- Vérifiez que vous êtes connecté au bon compte AWS

#### Erreur : "Certificate not validated"

- Le certificat doit être dans l'état **"Issued"** (pas "Pending validation")
- Vérifiez que les enregistrements DNS de validation sont correctement configurés dans Route53
- Attendez quelques minutes après la création des enregistrements DNS

#### Erreur : "Certificate in wrong region"

- CloudFront nécessite des certificats en **us-east-1**
- Si vous avez créé le certificat dans une autre région, recréez-le en us-east-1

### Références

- [Guide de configuration manuelle SES/ACM](./ACM_SES_MANUAL_SETUP.md) - Instructions détaillées pour créer les certificats
- [Guide des variables tfvars](./TERRAFORM_TFVARS_EXAMPLE.md) - Documentation complète des variables tfvars

## 11. Ressources supplémentaires

- [Documentation Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [README principal](./README.md) - Architecture détaillée et workflows
- [Documentation application](../../kambriq/docs/configuration/ENVIRONMENT_VARIABLES.md) - Variables d'environnement utilisées par l'app

