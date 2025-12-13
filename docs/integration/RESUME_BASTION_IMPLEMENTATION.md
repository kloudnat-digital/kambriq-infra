# Résumé de l'Implémentation : Bastion pour Migrations Prisma

**Date** : 2025-12-10  
**Objectif** : Solution temporaire pour exécuter manuellement les migrations Prisma via un bastion Ubuntu, remplaçant l'exécution automatique au démarrage de la Lambda.

---

## ✅ Livrables Complétés

### A) Module Terraform Bastion

#### Nouveaux Fichiers

**`modules/bastion/main.tf`** :
- Instance EC2 Ubuntu 22.04 LTS (t3.micro)
- Security Group bastion (SSH ingress depuis `allowed_ssh_cidr`, egress PostgreSQL vers RDS)
- Security Group Rule : Ajout ingress RDS depuis bastion (non destructif)
- User-data : Installation Node.js 22/20, pnpm v9, git, postgresql-client
- Lambda auto-stop (EventBridge cron 21:00 UTC = 23:00 Europe/Paris)
- IAM Role et Policy pour Lambda auto-stop (permissions minimales)

**`modules/bastion/variables.tf`** :
- `env`, `project_name`, `vpc_id`, `public_subnet_id`
- `rds_security_group_id` (pour ajouter règle ingress)
- `bastion_key_pair_name` (Key Pair existant, pas de création)
- `allowed_ssh_cidr` (CIDR autorisé pour SSH)
- `instance_type` (défaut: t3.micro)
- `enable_autostop` (défaut: true)
- `aws_region` (défaut: eu-central-1)

**`modules/bastion/outputs.tf`** :
- `bastion_public_ip`
- `bastion_instance_id`
- `bastion_security_group_id`
- `bastion_private_ip`
- `bastion_ssh_command` (exemple)

**`modules/bastion/README.md`** :
- Documentation complète d'utilisation
- Guide de connexion SSH
- Instructions pour migrations Prisma
- Tunnel SSH pour outils GUI
- Dépannage et commandes utiles

#### Intégration dans les Environnements

**`envs/dev/main.tf`** :
- Module bastion conditionnel (`count = var.enable_bastion ? 1 : 0`)
- `enable_bastion = true` par défaut (via variables.tf)
- Utilise premier subnet public du VPC

**`envs/dev/variables.tf`** :
- `enable_bastion` (défaut: `true`)
- `bastion_key_pair_name` (défaut: `""`)
- `allowed_ssh_cidr` (défaut: `""`)
- `enable_bastion_autostop` (défaut: `true`)

**`envs/dev/outputs.tf`** :
- Outputs bastion (conditionnels si `enable_bastion = true`)

**`envs/prod/main.tf`** :
- Module bastion conditionnel (identique à DEV)
- `enable_bastion = false` par défaut (sécurité)

**`envs/prod/variables.tf`** :
- Variables identiques à DEV
- `enable_bastion` (défaut: `false`)

**`envs/prod/outputs.tf`** :
- Outputs bastion (conditionnels)

### B) Désactivation Migrations Prisma Runtime

**`kambriq/api/src/main.ts`** :
- Appel `PrismaMigrationService.runMigrationsBeforeStartup()` commenté
- Commentaire explicatif avec référence à la documentation bastion

**`kambriq/api/src/lambda.ts`** :
- Appel `PrismaMigrationService.runMigrationsBeforeStartup()` commenté
- Commentaire explicatif avec référence à la documentation bastion

**Note** : `PrismaMigrationService` reste dans les providers de `ApiModule` (non utilisé, mais ne casse pas l'injection NestJS).

### C) Documentation

**`docs/integration/BASTION_MIGRATIONS.md`** :
- Guide d'utilisation complet
- Instructions de déploiement
- Workflow de migration
- Sécurité et bonnes pratiques

---

## 🔧 Configuration Requise

### Variables Terraform à Configurer

Dans `envs/{dev,prod}/terraform.tfvars` :

```hcl
# Bastion Configuration
enable_bastion = true  # true en DEV, false en PROD par défaut
bastion_key_pair_name = "kambriq-bastion-key"  # Key Pair existant dans AWS
allowed_ssh_cidr = "1.2.3.4/32"  # Votre IP publique (/32 pour une IP unique)
enable_bastion_autostop = true  # Arrêt automatique à 23h00 Europe/Paris
```

### Prérequis

1. **Key Pair EC2** : Doit être créé manuellement dans AWS Console avant `terraform apply`
2. **IP Publique** : Connaître votre IP publique pour `allowed_ssh_cidr`
3. **Permissions AWS** : Terraform doit avoir les permissions pour créer EC2, Lambda, EventBridge

---

## 🚀 Déploiement

### 1. Créer le Key Pair (si nécessaire)

```bash
# Dans AWS Console : EC2 → Key Pairs → Create key pair
# Nom : kambriq-bastion-key
# Type : RSA
# Format : .pem (OpenSSH)
# Télécharger et stocker la clé privée de manière sécurisée
```

### 2. Configurer terraform.tfvars

```bash
cd kambriq-aws-iac-terraform/envs/dev

# Éditer terraform.tfvars (ou créer depuis terraform.tfvars.example)
# Ajouter les variables bastion
```

### 3. Appliquer Terraform

```bash
terraform plan
terraform apply
```

### 4. Récupérer les Informations

```bash
terraform output bastion_public_ip
terraform output bastion_instance_id
```

---

## 📝 Utilisation

### Connexion au Bastion

```bash
ssh -i ~/.ssh/kambriq-bastion-key.pem ubuntu@<bastion-public-ip>
```

### Exécution des Migrations

```bash
# Sur le bastion
export DATABASE_URL=$(aws ssm get-parameter \
  --name "/kambriq/dev/api/DATABASE_URL" \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text)

git clone https://github.com/<org>/kambriq.git
cd kambriq/api
pnpm install --frozen-lockfile
pnpm prisma:generate
pnpm prisma migrate deploy
```

---

## 🔒 Sécurité

### Mesures Implémentées

1. ✅ **Security Groups restrictifs** :
   - SSH uniquement depuis `allowed_ssh_cidr`
   - PostgreSQL uniquement vers RDS Security Group

2. ✅ **Pas de secrets persistés** :
   - `DATABASE_URL` récupéré depuis SSM à chaque utilisation
   - Pas de `.env` sur le bastion

3. ✅ **Auto-stop quotidien** :
   - Arrêt automatique à 23h00 Europe/Paris
   - Réduit les coûts et la surface d'attaque

4. ✅ **Désactivé par défaut en PROD** :
   - `enable_bastion = false` en PROD
   - Activation uniquement quand nécessaire

5. ✅ **Permissions Lambda minimales** :
   - Lambda auto-stop peut uniquement arrêter l'instance bastion spécifique

---

## 💰 Coûts

- **Instance EC2 t3.micro** : ~$7-10/mois si running 24/7
- **Avec auto-stop** : Coûts réduits si utilisation ponctuelle
- **Recommandation** : Arrêter manuellement après utilisation

---

## 📋 Checklist de Déploiement

- [ ] Key Pair EC2 créé dans AWS Console
- [ ] Variables bastion configurées dans `terraform.tfvars`
- [ ] `terraform plan` exécuté et vérifié
- [ ] `terraform apply` exécuté
- [ ] IP publique du bastion récupérée
- [ ] Connexion SSH testée
- [ ] Migrations Prisma testées sur le bastion
- [ ] Auto-stop vérifié (logs CloudWatch)

---

## 🔄 Prochaines Étapes

1. **Tester le déploiement** :
   - Appliquer Terraform en DEV
   - Vérifier la création du bastion
   - Tester la connexion SSH
   - Exécuter une migration de test

2. **Documentation équipe** :
   - Partager le guide avec l'équipe
   - Documenter le workflow de migration
   - Former l'équipe sur l'utilisation du bastion

3. **Solution permanente** (futur) :
   - Évaluer une solution permanente (Lambda dédiée, etc.)
   - Migrer vers la solution permanente
   - Retirer le bastion une fois la solution permanente en place

---

## 📚 Références

- **Module bastion** : `modules/bastion/`
- **Documentation complète** : `modules/bastion/README.md`
- **Guide d'intégration** : `docs/integration/BASTION_MIGRATIONS.md`
- **Configuration DEV** : `envs/dev/main.tf`
- **Configuration PROD** : `envs/prod/main.tf`

---

**Dernière mise à jour** : 2025-12-10  
**Version** : 1.0  
**Statut** : ✅ Implémentation complète
