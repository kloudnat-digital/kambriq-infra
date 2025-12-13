# Bastion Partagé entre Dev et Prod

## Vue d'Ensemble

Le bastion est maintenant déployé dans le stack **`shared`** et est **partagé entre les environnements dev et prod**. Cela permet :

- ✅ Une seule instance EC2 pour les deux environnements
- ✅ Réduction des coûts (une seule instance au lieu de deux)
- ✅ Accès aux deux bases de données RDS (dev et prod)
- ✅ IP publique fixe via Elastic IP (EIP)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BASTION PARTAGÉ                           │
└─────────────────────────────────────────────────────────────┘

Internet (SSH depuis IP autorisée)
    │
    ▼
┌──────────────────────┐
│ Bastion EC2 (shared) │
│ - Ubuntu 22.04 LTS   │
│ - Elastic IP (EIP)   │
│ - Public Subnet      │
└──────────────────────┘
    │ (Security Groups)
    ├──► RDS DEV (Security Group dev)
    └──► RDS PROD (Security Group prod)
```

## Configuration

### Stack Shared

Le bastion est configuré dans `envs/shared/main.tf` :

```hcl
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "../../modules/bastion"

  env                   = "shared"
  project_name          = "kambriq"
  vpc_id                = module.shared.vpc_id
  public_subnet_id      = module.shared.public_subnet_ids[0]
  
  # Récupère les Security Groups RDS depuis dev et prod
  rds_security_group_ids = compact([
    try(data.terraform_remote_state.dev[0].outputs.rds_security_group_id, ""),
    try(data.terraform_remote_state.prod[0].outputs.rds_security_group_id, ""),
  ])

  bastion_key_pair_name = var.bastion_key_pair_name
  allowed_ssh_cidr      = var.allowed_ssh_cidr
  instance_type         = "t3.micro"
  enable_autostop       = var.enable_bastion_autostop
  aws_region            = var.aws_region
}
```

### Variables Requises (envs/shared/terraform.tfvars)

```hcl
enable_bastion = true
bastion_key_pair_name = "kambriq-bastion"
allowed_ssh_cidr = "90.25.230.44/32"
enable_bastion_autostop = true
```

## Déploiement

### Ordre de Déploiement

1. **Déployer shared** (crée le bastion sans accès RDS initialement)
   ```bash
   cd envs/shared
   terraform init
   terraform plan
   terraform apply
   ```

2. **Déployer dev** (crée RDS dev et Security Group)
   ```bash
   cd envs/dev
   terraform init
   terraform plan
   terraform apply
   ```

3. **Déployer prod** (crée RDS prod et Security Group)
   ```bash
   cd envs/prod
   terraform init
   terraform plan
   terraform apply
   ```

4. **Mettre à jour shared** (ajoute les règles Security Group pour accès RDS)
   ```bash
   cd envs/shared
   terraform plan  # Devrait montrer l'ajout des règles Security Group
   terraform apply
   ```

## Utilisation

### Connexion au Bastion

```bash
# Récupérer l'IP depuis le stack shared
cd envs/shared
terraform output bastion_public_ip

# Se connecter
ssh -i ~/.ssh/kambriq-bastion.pem ubuntu@<bastion-ip>
```

### Variables d'Environnement

Le bastion charge automatiquement `DATABASE_URL` au login. Par défaut, c'est l'environnement **dev**.

```bash
# Vérifier l'environnement actuel
echo $ENV  # dev (par défaut)

# Vérifier DATABASE_URL
echo $DATABASE_URL  # URL de la base dev

# Basculer vers prod
switch_env prod

# Vérifier le changement
echo $ENV  # prod
echo $DATABASE_URL  # URL de la base prod

# Revenir à dev
switch_env dev
```

### Exécution des Migrations

#### Pour DEV

```bash
# Sur le bastion (déjà connecté)
# DATABASE_URL est déjà chargé pour dev par défaut

git clone git@github.com:kloudnat-digital/kambriq.git
cd kambriq/api
pnpm install --frozen-lockfile
pnpm prisma:generate
pnpm prisma migrate deploy
```

#### Pour PROD

```bash
# Sur le bastion (déjà connecté)
# Basculer vers prod
switch_env prod

# Vérifier que DATABASE_URL est bien celui de prod
echo $DATABASE_URL

# Exécuter les migrations
cd kambriq/api  # Si déjà cloné
# Ou cloner à nouveau si nécessaire
pnpm prisma migrate deploy
```

## Fonctions Disponibles

### `switch_env <dev|prod>`

Change l'environnement actif et recharge `DATABASE_URL` :

```bash
switch_env dev   # Basculer vers dev
switch_env prod  # Basculer vers prod
```

### `refresh_db_url`

Rafraîchit `DATABASE_URL` pour l'environnement actuel :

```bash
refresh_db_url
```

## Sécurité

### Security Groups

- **Bastion SG** : SSH ingress depuis `allowed_ssh_cidr`, egress PostgreSQL vers RDS dev et prod
- **RDS DEV SG** : Ingress PostgreSQL depuis Bastion SG
- **RDS PROD SG** : Ingress PostgreSQL depuis Bastion SG

### Bonnes Pratiques

1. **Basculer l'environnement avant les migrations** :
   ```bash
   switch_env prod  # Avant migrations prod
   # Vérifier
   echo $ENV
   echo $DATABASE_URL
   ```

2. **Vérifier l'environnement avant d'exécuter** :
   ```bash
   # Toujours vérifier avant migrations critiques
   echo "Environment: $ENV"
   echo "Database: $DATABASE_URL"
   ```

3. **Utiliser des sessions SSH séparées** :
   - Une session pour dev
   - Une autre session pour prod
   - Évite les erreurs de basculement

## Dépannage

### Le bastion n'a pas accès à RDS

1. Vérifier que dev et prod sont déployés :
   ```bash
   cd envs/dev && terraform output rds_security_group_id
   cd envs/prod && terraform output rds_security_group_id
   ```

2. Mettre à jour shared pour ajouter les règles :
   ```bash
   cd envs/shared
   terraform plan  # Devrait montrer les règles Security Group à ajouter
   terraform apply
   ```

### DATABASE_URL ne se charge pas

```bash
# Recharger manuellement
refresh_db_url

# Ou basculer d'environnement
switch_env dev
```

### Vérifier l'accès RDS

```bash
# Tester la connexion à RDS dev
psql $DATABASE_URL -c "SELECT version();"

# Basculer vers prod et tester
switch_env prod
psql $DATABASE_URL -c "SELECT version();"
```

## Migration depuis Bastion par Environnement

Si vous aviez déjà un bastion dans dev ou prod :

1. **Détruire les anciens bastions** :
   ```bash
   cd envs/dev
   terraform destroy -target=module.bastion[0]
   
   cd envs/prod
   terraform destroy -target=module.bastion[0]
   ```

2. **Déployer le bastion dans shared** :
   ```bash
   cd envs/shared
   terraform apply
   ```

3. **Mettre à jour shared après déploiement dev/prod** :
   ```bash
   terraform apply  # Ajoute les règles Security Group
   ```

## Outputs

Les outputs du bastion sont disponibles dans le stack shared :

```bash
cd envs/shared
terraform output bastion_public_ip
terraform output bastion_instance_id
terraform output bastion_ssh_command
```

## Notes Importantes

- ⚠️ **Le bastion est partagé** : Toujours vérifier `$ENV` avant d'exécuter des migrations
- ✅ **IP fixe** : L'Elastic IP reste la même après redémarrage
- ✅ **Auto-stop** : Le bastion s'arrête automatiquement à 23h00 Europe/Paris
- ✅ **Accès aux deux RDS** : Le bastion peut accéder à dev et prod via Security Groups
