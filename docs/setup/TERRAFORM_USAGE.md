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
- Lambda (API NestJS)
- API Gateway (point d'entrée HTTP API)
- S3 (buckets pour frontend statique et médias)
- CloudFront (CDN pour le frontend)
- IAM (rôles et politiques)

## 2. Structure du repo

```
kambriq-aws-iac-terraform/
├── modules/              # Modules Terraform réutilisables
│   ├── shared/          # Ressources partagées (VPC, Route53, SES, ACM)
│   ├── network/         # Réseau (VPC, subnets, NAT Gateway)
│   ├── rds-postgres/    # Base de données PostgreSQL
│   ├── s3-static-site/  # Bucket S3 pour frontend Next.js
│   ├── s3-media/        # Bucket S3 pour médias/documents
│   ├── cloudfront/      # Distribution CloudFront
│   ├── lambda-api/      # Fonction Lambda pour API NestJS
│   ├── api-gateway/     # API Gateway HTTP API
│   ├── ses/             # Simple Email Service
│   └── iam/             # Rôles et policies IAM
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
  - Sur push vers `develop` : exécute `terraform plan` + `apply` automatiquement

- **`terraform-prod.yml`** : Gère l'infrastructure prod (même ressources que dev)
  - Déclenchement manuel (`workflow_dispatch`) avec choix `plan` ou `apply`
  - Ou déclenchement automatique sur tags `v*` (plan + apply)

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

1. **Pousser vers la branche `develop`** :
   - Le workflow `terraform-dev.yml` s'exécute automatiquement
   - Il fait un `terraform plan` + `apply` automatiquement (auto-approve)

2. **Vérifier les outputs** :
   - Les outputs non-sensibles sont affichés dans le résumé GitHub Actions
   - Pour voir tous les outputs : `terraform output` (localement) ou `terraform output -json` (dans le workflow)

### ⚠️ Important : Gestion des secrets

**Les secrets applicatifs (mot de passe DB, JWT secrets) ne sont PAS gérés via Terraform** :

- ❌ Ne pas passer `DB_PASSWORD_DEV` ou `JWT_SECRET_DEV` comme variables Terraform (`TF_VAR_*`)
- ❌ Ne pas stocker ces valeurs dans `terraform.tfvars` (ce fichier est ignoré par Git)
- ✅ Stocker les secrets dans **AWS SSM Parameter Store** ou **AWS Secrets Manager**
- ✅ Configurer les variables d'environnement Lambda directement (via Terraform ou AWS Console)
- ✅ Utiliser la convention de nommage : `/kambriq/{environment}/{parameter_name}`

Terraform ne gère que les ressources d'infrastructure, pas les secrets applicatifs.

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
   - Sélectionner "Terraform - Prod Environment"
   - Cliquer sur "Run workflow"
   - Choisir `action = plan` pour générer un plan
   - Réviser le plan dans les artifacts
   - Relancer avec `action = apply` pour appliquer

2. **Déclenchement automatique** (tags `v*`) :
   - Créer un tag : `git tag v1.0.0 && git push origin v1.0.0`
   - Le workflow `terraform-prod.yml` s'exécute automatiquement
   - Il fait un `terraform plan` puis `apply` si le tag correspond à `v*`

### ⚠️ Sécurité production

- **Toujours réviser le plan** avant d'appliquer en production
- **Ne jamais mettre de secrets applicatifs** dans les `terraform.tfvars` ou comme variables Terraform
- **Utiliser GitHub Environments** avec approbation manuelle (décommenter dans le workflow si nécessaire)
- **Vérifier les outputs** après chaque déploiement

## 7. Relation avec le repo applicatif (kambriq)

Ce dépôt Terraform gère uniquement l'infrastructure. Le code applicatif est dans le dépôt `kambriq`.

### Flux de déploiement

1. **Déployer l'infrastructure** (ce repo) :
   - Déployer `shared` → `dev` → `prod` (dans cet ordre)
   - Terraform génère des outputs (S3 bucket, CloudFront domain, API Gateway URL, Lambda function name)

2. **Déployer l'application** (repo `kambriq`) :
   - Le workflow `deploy-dev.yml` dans le repo applicatif :
     - Checkout ce repo Terraform
     - Lit les outputs Terraform depuis `envs/dev`
     - Utilise ces outputs pour configurer le build Next.js (`NEXT_PUBLIC_*` variables)
     - Déploie le frontend vers S3 + CloudFront
     - Déploie l'API vers Lambda (nom de fonction depuis Terraform outputs)

### Outputs Terraform utilisés par l'application

| Output Terraform | Utilisé par | Description |
|------------------|-------------|-------------|
| `frontend_cloudfront_domain` | `deploy-dev.yml` | Domaine CloudFront pour le frontend |
| `frontend_s3_bucket_name` | `deploy-dev.yml` | Bucket S3 pour déployer le frontend |
| `media_s3_public_bucket_name` | `deploy-dev.yml` | Bucket S3 pour médias publics |
| `api_gateway_base_url` | `deploy-dev.yml` | URL de l'API Gateway |
| `lambda_function_name` | `deploy-dev.yml` | Nom de la fonction Lambda |
| `region` | `deploy-dev.yml` | Région AWS |
| `ses_from_email` | `deploy-dev.yml` | Email expéditeur SES |

**Note** : Les secrets (DB password, JWT secrets) ne sont PAS dans les outputs Terraform. Ils sont gérés via SSM Parameter Store / Secrets Manager et configurés dans les variables d'environnement Lambda.

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

