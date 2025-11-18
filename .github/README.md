# GitHub Actions - Déploiement Infrastructure

## Configuration requise

### Secrets GitHub

Configurer les secrets suivants dans GitHub (Settings → Secrets and variables → Actions) :

#### Secrets globaux (utilisés par tous les environnements)
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS avec permissions pour créer les ressources
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS

#### Secrets par environnement
Créer des environnements GitHub (`dev` et `prod`) dans Settings → Environments et y ajouter :

**Environnement `dev` :**
- `DB_PASSWORD` : Mot de passe de la base de données (dev)
- `JWT_SECRET` : Secret JWT pour l'authentification (dev)

**Environnement `prod` :**
- `DB_PASSWORD` : Mot de passe de la base de données (prod)
- `JWT_SECRET` : Secret JWT pour l'authentification (prod)

## Déclencheurs

### Push automatique
- **Branche `main`** → Déploie automatiquement en **production**
- **Branche `develop`** → Déploie automatiquement en **dev**

### Pull Request
- Exécute `terraform plan` et commente le PR avec le plan

### Déploiement manuel
1. Aller dans Actions → Deploy Infrastructure
2. Cliquer sur "Run workflow"
3. Choisir :
   - **Environment** : `dev` ou `prod`
   - **Action** : `plan`, `apply`, ou `destroy`

## Permissions AWS requises

Le rôle/utilisateur AWS doit avoir les permissions pour :
- S3 (backend state, buckets)
- RDS (création de base de données)
- Lambda (création et gestion de fonctions)
- API Gateway (création d'APIs)
- CloudFront (création de distributions)
- SES (gestion d'identités)
- IAM (création de rôles et policies)
- VPC (gestion de security groups)
- CloudWatch Logs (pour Lambda)

