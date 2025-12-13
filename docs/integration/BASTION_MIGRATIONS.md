# Solution Temporaire : Bastion pour Migrations Prisma

## Vue d'Ensemble

Cette solution temporaire fournit un bastion Ubuntu pour exécuter manuellement les migrations Prisma vers la base de données RDS PostgreSQL privée, remplaçant l'exécution automatique au démarrage de la Lambda.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE BASTION                      │
└─────────────────────────────────────────────────────────────┘

Internet (SSH depuis IP autorisée)
    │
    ▼
┌──────────────────────┐
│ Bastion EC2          │
│ - Ubuntu 22.04 LTS   │
│ - Public Subnet      │
│ - Node.js 22/20      │
│ - pnpm v9            │
│ - git, postgresql-client │
└──────────────────────┘
    │ (Security Group: PostgreSQL 5432)
    ▼
┌──────────────────────┐
│ RDS PostgreSQL       │
│ - Private Subnet     │
│ - Security Group     │
│   (Lambda + Bastion) │
└──────────────────────┘
```

## Configuration Terraform

### Variables Requises

Dans `envs/{dev,prod}/terraform.tfvars` :

```hcl
# Bastion Configuration
enable_bastion = true  # true en DEV, false en PROD par défaut
bastion_key_pair_name = "kambriq-bastion-key"  # Key Pair existant dans AWS
allowed_ssh_cidr = "1.2.3.4/32"  # Votre IP publique (/32 pour une IP unique)
enable_bastion_autostop = true  # Arrêt automatique à 23h00
```

### Création du Key Pair (si nécessaire)

Le Key Pair doit être créé **manuellement** dans AWS Console :

1. Aller dans **EC2 → Key Pairs → Create key pair**
2. Nom : `kambriq-bastion-key` (ou autre nom selon votre configuration)
3. Type : RSA
4. Format : `.pem` (OpenSSH)
5. Télécharger la clé privée et la stocker de manière sécurisée

**⚠️ Important** : Le Key Pair doit exister **avant** d'exécuter `terraform apply`.

## Déploiement

### 1. Appliquer Terraform

```bash
cd kambriq-aws-iac-terraform/envs/dev

# Vérifier le plan
terraform plan

# Appliquer (crée le bastion)
terraform apply
```

### 2. Récupérer les Informations du Bastion

```bash
# IP publique
terraform output bastion_public_ip

# Instance ID
terraform output bastion_instance_id

# Commande SSH
terraform output bastion_ssh_command
```

## Utilisation

### Connexion au Bastion

```bash
ssh -i ~/.ssh/kambriq-bastion-key.pem ubuntu@<bastion-public-ip>
```

### Exécution des Migrations

Une fois connecté au bastion :

```bash
# 1. Récupérer DATABASE_URL depuis SSM
export DATABASE_URL=$(aws ssm get-parameter \
  --name "/kambriq/dev/api/DATABASE_URL" \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text)

# 2. Cloner le repository
git clone https://github.com/<org>/kambriq.git
cd kambriq/api

# 3. Installer les dépendances
pnpm install --frozen-lockfile

# 4. Générer le client Prisma
pnpm prisma:generate

# 5. Exécuter les migrations
pnpm prisma migrate deploy
```

## Tunnel SSH pour Outils GUI

Pour utiliser pgAdmin, DBeaver, ou autre outil GUI :

```bash
# Depuis votre machine locale
ssh -i ~/.ssh/kambriq-bastion-key.pem \
  -L 5433:<rds-endpoint>:5432 \
  -N \
  ubuntu@<bastion-public-ip>
```

Puis connectez-vous à :
- **Host** : `localhost`
- **Port** : `5433`
- **Database** : `kambriq`
- **User** : `kambriq_admin`
- **Password** : Récupéré depuis SSM (`/kambriq/{env}/db/password`)

## Auto-stop Quotidien

Le bastion s'arrête automatiquement à **23:00 Europe/Paris (21:00 UTC)** pour réduire les coûts.

### Redémarrer le Bastion

```bash
aws ec2 start-instances --instance-ids <bastion-instance-id>
```

### Vérifier l'État

```bash
aws ec2 describe-instances \
  --instance-ids <bastion-instance-id> \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text
```

## Sécurité

### ⚠️ Bonnes Pratiques

1. **Restreindre l'accès SSH** :
   - Utiliser `allowed_ssh_cidr` avec une IP spécifique (`/32`)
   - Ne jamais utiliser `0.0.0.0/0` en production

2. **Désactiver en PROD** :
   - `enable_bastion = false` par défaut en PROD
   - Activer uniquement quand nécessaire
   - Désactiver après utilisation

3. **Key Pair sécurisé** :
   - Utiliser un Key Pair avec passphrase
   - Stocker la clé privée de manière sécurisée
   - Ne jamais commiter la clé privée

4. **Pas de secrets persistés** :
   - Récupérer `DATABASE_URL` depuis SSM à chaque utilisation
   - Ne pas créer de `.env` sur le bastion

## Coûts

- **Instance EC2 t3.micro** : ~$7-10/mois si running 24/7
- **Avec auto-stop** : Coûts réduits si utilisation ponctuelle
- **Recommandation** : Arrêter manuellement après utilisation

## Dépannage

### Le bastion ne démarre pas

```bash
# Vérifier l'état
aws ec2 describe-instances --instance-ids <bastion-instance-id>

# Démarrer
aws ec2 start-instances --instance-ids <bastion-instance-id>
```

### Connexion SSH échoue

1. Vérifier que votre IP est dans `allowed_ssh_cidr`
2. Vérifier que le Key Pair est correct
3. Vérifier que l'instance est `running`
4. Vérifier les Security Groups

### Migrations échouent

1. Vérifier `DATABASE_URL` depuis SSM
2. Vérifier que le Security Group RDS autorise le bastion
3. Tester la connectivité :
   ```bash
   psql -h <rds-endpoint> -U kambriq_admin -d kambriq
   ```

## Migration depuis Runtime Lambda

Les migrations Prisma ont été **désactivées** dans le runtime Lambda :

- ✅ `api/src/main.ts` : Appel commenté
- ✅ `api/src/lambda.ts` : Appel commenté
- ✅ `PrismaMigrationService` reste dans les providers (non utilisé)

Les migrations doivent maintenant être exécutées **manuellement via le bastion**.

## Références

- **Documentation complète** : `modules/bastion/README.md`
- **Module Terraform** : `modules/bastion/`
- **Configuration DEV** : `envs/dev/main.tf`
- **Configuration PROD** : `envs/prod/main.tf`
