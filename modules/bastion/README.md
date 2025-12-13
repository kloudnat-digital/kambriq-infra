# Module Bastion - Guide d'Utilisation

## Vue d'Ensemble

Le module bastion fournit une instance EC2 Ubuntu dans un subnet public pour permettre l'exécution manuelle de migrations Prisma vers la base de données RDS PostgreSQL qui se trouve dans un subnet privé.

**⚠️ Solution temporaire** : Cette solution est temporaire jusqu'à ce qu'une solution permanente soit mise en place (par exemple, migrations via Lambda dédiée ou autre mécanisme).

## Architecture

```
Internet
    │
    ▼
┌──────────────────────┐
│ Bastion (Public)    │
│ - Ubuntu 22.04 LTS  │
│ - Node.js 22/20      │
│ - pnpm v9           │
│ - git, postgresql-client │
└──────────────────────┘
    │ (SSH tunnel)
    ▼
┌──────────────────────┐
│ RDS PostgreSQL       │
│ (Private Subnet)     │
└──────────────────────┘
```

## Configuration

### Variables Requises

- `bastion_key_pair_name` : Nom du Key Pair EC2 existant dans AWS (doit être créé manuellement dans AWS Console)
- `allowed_ssh_cidr` : CIDR block autorisé pour SSH (ex: `1.2.3.4/32` pour une IP unique)
- `enable_bastion` : Activer/désactiver le bastion (true par défaut en DEV, false en PROD)
- `enable_bastion_autostop` : Activer l'arrêt automatique quotidien à 23h00 (true par défaut)

### Auto-stop Quotidien

Le bastion s'arrête automatiquement tous les jours à **23:00 Europe/Paris (21:00 UTC)** pour réduire les coûts.

- **EventBridge Rule** : Cron `0 21 * * ? *` (21:00 UTC)
- **Lambda Function** : Arrête l'instance si elle est en cours d'exécution
- **Permissions minimales** : Lambda peut uniquement arrêter l'instance bastion spécifique

Pour redémarrer le bastion manuellement :
```bash
aws ec2 start-instances --instance-ids <bastion-instance-id>
```

## Connexion au Bastion

### 1. Récupérer l'IP Publique

```bash
# Via Terraform outputs (après terraform apply)
terraform output bastion_public_ip

# Ou via AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=kambriq-bastion-{env}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### 2. Connexion SSH

```bash
ssh -i <path-to-private-key.pem> ubuntu@<bastion-public-ip>
```

**Exemple** :
```bash
ssh -i ~/.ssh/kambriq-bastion-key.pem ubuntu@54.123.45.67
```

## Exécution des Migrations Prisma

### 1. Connexion au Bastion

```bash
ssh -i <private-key.pem> ubuntu@<bastion-public-ip>
```

### 2. Cloner le Repository

```bash
# Installer AWS CLI si nécessaire (déjà installé via user-data)
# Récupérer DATABASE_URL depuis SSM
export DATABASE_URL=$(aws ssm get-parameter \
  --name "/kambriq/{env}/api/DATABASE_URL" \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text)

# Cloner le repository
git clone https://github.com/<org>/kambriq.git
cd kambriq/api
```

### 3. Installer les Dépendances

```bash
pnpm install --frozen-lockfile
```

### 4. Exécuter les Migrations

```bash
# Générer le client Prisma
pnpm prisma:generate

# Appliquer les migrations
pnpm prisma migrate deploy
```

**Note** : `prisma migrate deploy` est idempotent et sûr pour la production (n'applique que les migrations non appliquées).

## Tunnel SSH vers RDS (Optionnel - pour outils GUI)

Si vous souhaitez utiliser un outil GUI (pgAdmin, DBeaver, etc.) depuis votre machine locale :

### 1. Créer le Tunnel SSH

```bash
ssh -i <private-key.pem> \
  -L 5433:<rds-endpoint>:5432 \
  -N \
  ubuntu@<bastion-public-ip>
```

**Exemple** :
```bash
ssh -i ~/.ssh/kambriq-bastion-key.pem \
  -L 5433:kambriq-postgres-dev.ceqjohmcfzzp.eu-central-1.rds.amazonaws.com:5432 \
  -N \
  ubuntu@54.123.45.67
```

Le flag `-N` empêche l'exécution de commandes distantes (tunnel uniquement).

### 2. Connexion depuis un Outil GUI

Une fois le tunnel actif, connectez-vous à PostgreSQL depuis votre machine locale :

- **Host** : `localhost`
- **Port** : `5433` (port local du tunnel)
- **Database** : `kambriq`
- **User** : `kambriq_admin`
- **Password** : Récupéré depuis SSM Parameter Store

### 3. Récupérer le Mot de Passe

```bash
aws ssm get-parameter \
  --name "/kambriq/{env}/db/password" \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text
```

## Sécurité

### ⚠️ Bonnes Pratiques

1. **Ne pas stocker de secrets dans le bastion** :
   - Les secrets sont récupérés depuis SSM Parameter Store à chaque utilisation
   - Pas de `.env` commité ou persistant

2. **Restreindre l'accès SSH** :
   - Utiliser `allowed_ssh_cidr` avec une IP spécifique (`/32`)
   - Ne jamais utiliser `0.0.0.0/0` en production

3. **Désactiver le bastion quand non utilisé** :
   - En PROD : `enable_bastion = false` par défaut
   - Activer uniquement quand nécessaire pour migrations
   - Désactiver après utilisation

4. **Auto-stop activé** :
   - Le bastion s'arrête automatiquement à 23h00
   - Réduit les coûts et la surface d'attaque

5. **Key Pair sécurisé** :
   - Utiliser un Key Pair avec passphrase
   - Stocker la clé privée de manière sécurisée
   - Ne jamais commiter la clé privée

### Security Groups

- **Bastion SG** :
  - Ingress : SSH (22) uniquement depuis `allowed_ssh_cidr`
  - Egress : PostgreSQL (5432) vers RDS SG uniquement
  - Egress : HTTPS/HTTP pour package installation

- **RDS SG** :
  - Ingress : PostgreSQL (5432) depuis Lambda SG (existant)
  - Ingress : PostgreSQL (5432) depuis Bastion SG (ajouté par le module)

## Coûts

- **Instance EC2** : t3.micro (~$7-10/mois si running 24/7)
- **Auto-stop activé** : Réduit les coûts si le bastion n'est utilisé que ponctuellement
- **Recommandation** : Arrêter le bastion manuellement après utilisation si auto-stop n'est pas suffisant

## Dépannage

### Le bastion ne démarre pas

```bash
# Vérifier l'état de l'instance
aws ec2 describe-instances \
  --instance-ids <bastion-instance-id> \
  --query 'Reservations[0].Instances[0].State.Name'

# Démarrer l'instance
aws ec2 start-instances --instance-ids <bastion-instance-id>
```

### Connexion SSH échoue

1. Vérifier que l'IP source est dans `allowed_ssh_cidr`
2. Vérifier que le Key Pair est correct
3. Vérifier que l'instance est en état `running`
4. Vérifier les Security Groups (SSH ingress depuis votre IP)

### Migrations Prisma échouent

1. Vérifier que `DATABASE_URL` est correctement récupéré depuis SSM
2. Vérifier que le Security Group RDS autorise le bastion
3. Vérifier la connectivité réseau :
   ```bash
   # Depuis le bastion
   psql -h <rds-endpoint> -U kambriq_admin -d kambriq
   ```

### Auto-stop ne fonctionne pas

1. Vérifier les logs CloudWatch de la Lambda :
   ```bash
   aws logs tail /aws/lambda/kambriq-bastion-{env}-autostop --follow
   ```

2. Vérifier que l'EventBridge Rule est active :
   ```bash
   aws events describe-rule --name kambriq-bastion-{env}-autostop-schedule
   ```

## Commandes Utiles

### Démarrer le Bastion

```bash
aws ec2 start-instances --instance-ids <bastion-instance-id>
```

### Arrêter le Bastion

```bash
aws ec2 stop-instances --instance-ids <bastion-instance-id>
```

### Vérifier l'État

```bash
aws ec2 describe-instances \
  --instance-ids <bastion-instance-id> \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]' \
  --output table
```

### Récupérer l'IP Publique

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=kambriq-bastion-{env}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

## Workflow Complet de Migration

```bash
# 1. Démarrer le bastion (si arrêté)
aws ec2 start-instances --instance-ids <bastion-instance-id>
# Attendre que l'instance soit "running" (~30 secondes)

# 2. Se connecter au bastion
ssh -i <private-key.pem> ubuntu@<bastion-public-ip>

# 3. Sur le bastion : Récupérer DATABASE_URL
export DATABASE_URL=$(aws ssm get-parameter \
  --name "/kambriq/{env}/api/DATABASE_URL" \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text)

# 4. Cloner et préparer
git clone https://github.com/<org>/kambriq.git
cd kambriq/api
pnpm install --frozen-lockfile
pnpm prisma:generate

# 5. Exécuter les migrations
pnpm prisma migrate deploy

# 6. Vérifier le résultat
echo "Migrations completed successfully"

# 7. Se déconnecter et arrêter le bastion (optionnel)
exit
aws ec2 stop-instances --instance-ids <bastion-instance-id>
```

## Notes Importantes

- ⚠️ **Ne jamais commiter de secrets** dans le repository cloné sur le bastion
- ⚠️ **Désactiver le bastion** après utilisation en PROD
- ✅ **Auto-stop activé** par défaut pour réduire les coûts
- ✅ **Security Groups restrictifs** pour minimiser la surface d'attaque
- ✅ **Solution temporaire** jusqu'à mise en place d'une solution permanente
