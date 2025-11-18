# KAMBRIQ AWS Infrastructure as Code (Terraform)

Infrastructure Terraform modulaire pour l'application KAMBRIQ sur AWS.

## Structure du projet

```
.
├── modules/              # Modules Terraform réutilisables
│   ├── network/         # VPC et networking (optionnel)
│   ├── rds-postgres/   # Base de données PostgreSQL
│   ├── s3-static-site/  # Bucket S3 pour frontend Next.js
│   ├── s3-media/       # Bucket S3 pour médias/documents
│   ├── cloudfront/      # Distribution CloudFront
│   ├── lambda-api/      # Fonction Lambda pour API NestJS
│   ├── api-gateway/     # API Gateway HTTP API
│   ├── ses/            # Configuration SES pour emails
│   └── iam/            # Rôles et policies IAM
├── envs/               # Configurations par environnement
│   ├── dev/           # Environnement de développement
│   └── prod/          # Environnement de production
└── versions.tf         # Contraintes de versions
```

## Architecture

- **Frontend**: Next.js static export → S3 + CloudFront
- **Backend**: NestJS API → Lambda + API Gateway (HTTP API)
- **Database**: PostgreSQL RDS (t4g.micro, Single-AZ, 20Go gp3)
- **Storage**: S3 pour médias et documents (privé + public)
- **Email**: SES avec domaine kambriq.com
- **Auth**: JWT maison (pas de Cognito pour l'instant)

## Déploiement

### Prérequis

1. Installer Terraform (>= 1.5.0)
2. Configurer les credentials AWS (via `aws configure` ou variables d'environnement)
3. Le backend S3 est configuré : `kloudnat-infra-shared-store` dans `eu-central-1`

### Déploiement via GitHub Actions (Recommandé)

La pipeline GitHub Actions déploie automatiquement l'infrastructure :

- **Branche `main`** → Déploie en **production**
- **Branche `develop`** → Déploie en **dev**
- **Pull Requests** → Exécute `terraform plan` et commente le PR

#### Secrets GitHub requis

Configurer les secrets suivants dans GitHub (Settings → Secrets and variables → Actions) :

- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS
- `DB_PASSWORD` : Mot de passe de la base de données
- `JWT_SECRET` : Secret JWT pour l'authentification

#### Déploiement manuel via GitHub Actions

1. Aller dans l'onglet "Actions" du repository
2. Sélectionner "Deploy Infrastructure"
3. Cliquer sur "Run workflow"
4. Choisir l'environnement (dev/prod) et l'action (plan/apply/destroy)

### Déploiement local

#### Environnement de développement

```bash
cd envs/dev
# Les fichiers terraform.tfvars sont déjà créés (mais ignorés par git)
# Éditer terraform.tfvars avec vos valeurs réelles

terraform init
terraform plan
terraform apply
```

#### Environnement de production

```bash
cd envs/prod
# Les fichiers terraform.tfvars sont déjà créés (mais ignorés par git)
# Éditer terraform.tfvars avec vos valeurs réelles

terraform init
terraform plan
terraform apply
```

**Note** : Les fichiers `terraform.tfvars` sont ignorés par git (`.gitignore`) pour des raisons de sécurité. Ils contiennent des valeurs par défaut à remplacer.

## Variables d'environnement

Les outputs Terraform fournissent les informations nécessaires pour configurer l'application :

- URL CloudFront du frontend
- URL API Gateway
- Identifiants de connexion à la base de données (host, port, database name)
- ARN SES pour l'envoi d'emails

## Backend Terraform (État)

L'état Terraform est stocké dans S3 : `kloudnat-infra-shared-store`

- **Dev** : `kambriq/dev/terraform.tfstate`
- **Prod** : `kambriq/prod/terraform.tfstate`

Région : `eu-central-1`

La configuration est déjà définie dans `envs/*/backend.tf`.

## TODO

- [x] Migrer l'état Terraform vers S3 backend
- [ ] Ajouter des alarmes CloudWatch pour monitoring
- [ ] Configurer des backups automatiques pour RDS
- [ ] Ajouter des variables pour les secrets (via AWS Secrets Manager)
- [ ] Configurer des domaines personnalisés pour CloudFront et API Gateway
- [ ] Ajouter des règles de sécurité supplémentaires (WAF, etc.)
- [ ] Optimiser les coûts avec Reserved Instances ou Savings Plans (si applicable)

## Coûts estimés (MVP)

- RDS t4g.micro: ~$15-20/mois
- Lambda: Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- API Gateway: Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- S3: ~$0.023/Go/mois
- CloudFront: Pay-per-use (gratuit jusqu'à 1To/mois)
- SES: Gratuit jusqu'à 62,000 emails/mois

Total estimé MVP: ~$20-30/mois (hors trafic)

## Notes

- Les mots de passe de base de données sont actuellement gérés via des variables. Pour la production, migrer vers AWS Secrets Manager.
- Le VPC utilise la VPC par défaut pour simplifier. Pour la production, créer un VPC dédié avec des sous-réseaux privés.
- Les ressources sont configurées pour minimiser les coûts tout en restant fonctionnelles.

