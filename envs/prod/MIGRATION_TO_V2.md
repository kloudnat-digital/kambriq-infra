# Migration PROD vers V2 - Guide

**Status :** ⚠️ **À FAIRE**

---

## Situation Actuelle

L'environnement `prod` utilise encore l'architecture V1 :
- Lambda + OpenNext + NestJS + API Gateway
- Modules Terraform V1 : `frontend`, `lambda-api`, `api-gateway`

**⚠️ ATTENTION :** Les modules V1 ont été supprimés du repository. Cette configuration ne fonctionnera plus si vous tentez de l'appliquer.

---

## Plan de Migration

### 1. Créer Configuration V2

```bash
cd kambriq-aws-iac-terraform
cp -r envs/dev-v2 envs/prod-v2
```

### 2. Adapter Configuration PROD

Modifier `envs/prod-v2/main.tf` pour :
- Changer `env = "dev"` → `env = "prod"`
- Ajuster les tailles d'instances (plus grandes en prod)
- Configurer les domaines prod (`kambriq.com` au lieu de `dev.kambriq.com`)
- Ajuster les paramètres de backup RDS (30 jours)
- Configurer les certificats ACM prod

### 3. Déployer Infrastructure V2

```bash
cd envs/prod-v2
terraform init
terraform plan
terraform apply
```

### 4. Migrer Données (si nécessaire)

- Vérifier que la base de données RDS est accessible
- Exécuter les migrations Alembic si nécessaire
- Vérifier les données existantes

### 5. Déployer Applications V2

- Build et push images Docker vers ECR prod
- Déployer services ECS
- Vérifier health checks

### 6. Basculer DNS

- Mettre à jour Route53 pour pointer vers CloudFront V2
- Vérifier que tout fonctionne

### 7. Nettoyer V1

Une fois V2 validé et stable :
- Détruire infrastructure V1 prod
- Supprimer `envs/prod/` (V1)

---

## Référence

Voir `envs/dev-v2/` pour la configuration V2 de référence.

Voir `docs/MIGRATION_COMPLETE.md` pour les détails de la migration dev.

---

**Status :** ⚠️ **MIGRATION PROD À PLANIFIER**

