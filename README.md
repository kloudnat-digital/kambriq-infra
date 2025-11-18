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
3. Créer un fichier `terraform.tfvars` dans `envs/dev/` ou `envs/prod/` (voir `terraform.tfvars.example`)

### Environnement de développement

```bash
cd envs/dev
# Copier et éditer terraform.tfvars.example vers terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs

terraform init
terraform plan
terraform apply
```

### Environnement de production

```bash
cd envs/prod
# Copier et éditer terraform.tfvars.example vers terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs

terraform init
terraform plan
terraform apply
```

## Variables d'environnement

Les outputs Terraform fournissent les informations nécessaires pour configurer l'application :

- URL CloudFront du frontend
- URL API Gateway
- Identifiants de connexion à la base de données (host, port, database name)
- ARN SES pour l'envoi d'emails

## Backend Terraform (État)

Actuellement, l'état Terraform est stocké localement. Pour la production, il est recommandé de migrer vers un backend S3 :

1. Créer un bucket S3 pour l'état Terraform
2. Configurer le backend dans `envs/*/backend.tf`
3. Migrer l'état existant avec `terraform init -migrate-state`

Exemple de configuration backend S3 :

```hcl
terraform {
  backend "s3" {
    bucket = "kambriq-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "eu-west-1"
  }
}
```

## TODO

- [ ] Migrer l'état Terraform vers S3 backend
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

