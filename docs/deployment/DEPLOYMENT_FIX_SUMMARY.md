# Résumé des Corrections de Déploiement - 2026-01-03

## Problèmes Identifiés

### 1. **Erreur d'Architecture Docker** ✅ CORRIGÉ
- **Symptôme**: `exec /usr/local/bin/python: exec format error`
- **Cause**: Images Docker construites pour ARM64 (Mac M1/M2) alors qu'ECS Fargate utilise AMD64
- **Solution**: Ajout de `--platform linux/amd64` dans tous les Dockerfiles et scripts de build
- **Fichiers modifiés**:
  - `kambriq/apps/api/Dockerfile`
  - `kambriq/apps/web/Dockerfile`
  - `kambriq/scripts/deploy-local.sh`
  - `kambriq/.github/workflows/deploy-dev.yml`
  - `kambriq/.github/workflows/deploy-prod.yml`

### 2. **Erreur d'Authentification PostgreSQL** ✅ CORRIGÉ
- **Symptôme**: `password authentication failed for user "kambriq_admin"`
- **Cause**: Le mot de passe dans SSM Parameter Store ne correspondait pas au mot de passe réel de RDS
- **Solution**: Mise à jour du mot de passe RDS via `aws rds modify-db-instance` pour correspondre au mot de passe dans SSM
- **Commande exécutée**:
  ```bash
  aws rds modify-db-instance \
    --db-instance-identifier kambriq-postgres-dev \
    --master-user-password "$(aws ssm get-parameter --name /kambriq/dev/db/password --with-decryption --query 'Parameter.Value' --output text)" \
    --apply-immediately \
    --region eu-central-1
  ```

### 3. **Paramètre SSL Supprimé de DATABASE_URL** ✅ CORRIGÉ
- **Symptôme**: `no pg_hba.conf entry for host ..., no encryption`
- **Cause**: Le code supprimait tous les paramètres de requête de l'URL, y compris `sslmode=require`
- **Solution**: Modification du code pour préserver `sslmode` tout en supprimant uniquement `schema=public`
- **Fichiers modifiés**:
  - `kambriq/apps/api/app/config.py` (méthodes `__init__` et `_load_from_ssm`)
  - `kambriq/apps/api/app/infrastructure/database/session.py` (fonction `_create_engine`)

### 4. **URL de Base de Données dans SSM** ✅ CORRIGÉ
- **Action**: Mise à jour de `/kambriq/dev/db/url` pour inclure `?sslmode=require`
- **Commande exécutée**:
  ```bash
  aws ssm put-parameter \
    --name /kambriq/dev/db/url \
    --value "postgresql://kambriq_admin:PASSWORD@HOST:5432/kambriq?sslmode=require" \
    --type SecureString \
    --overwrite \
    --region eu-central-1
  ```

## État Final

### Services ECS
- ✅ **kambriq-dev-api**: 1/1 tâche en cours - ACTIVE
- ✅ **kambriq-dev-web**: 1/1 tâche en cours - ACTIVE

### Base de Données
- ✅ RDS PostgreSQL disponible et accessible
- ✅ Mot de passe synchronisé entre SSM et RDS
- ✅ SSL activé (`sslmode=require`)

### Logs
- ✅ Migrations Alembic s'exécutent correctement
- ✅ API démarre sans erreurs
- ✅ Plus d'erreurs de connexion à la base de données

## Leçons Apprises

1. **Architecture Docker**: Toujours spécifier `--platform linux/amd64` pour les builds destinés à ECS Fargate
2. **Synchronisation Secrets**: S'assurer que les secrets dans SSM correspondent aux valeurs réelles dans les services AWS (RDS, etc.)
3. **Paramètres d'URL**: Préserver les paramètres importants (comme `sslmode`) lors du nettoyage des URLs de base de données
4. **Validation**: Toujours vérifier les logs CloudWatch après un déploiement pour identifier les problèmes rapidement

## Commandes Utiles pour le Débogage

```bash
# Vérifier l'état des services
aws ecs describe-services --cluster kambriq-dev-cluster --services kambriq-dev-api kambriq-dev-web --region eu-central-1

# Vérifier les logs
aws logs tail /ecs/kambriq-dev-api --region eu-central-1 --since 1h
aws logs tail /ecs/kambriq-dev-api-migrations --region eu-central-1 --since 1h

# Vérifier les secrets SSM
aws ssm get-parameter --name /kambriq/dev/db/url --with-decryption --region eu-central-1
aws ssm get-parameter --name /kambriq/dev/db/password --with-decryption --region eu-central-1

# Vérifier l'état RDS
aws rds describe-db-instances --db-instance-identifier kambriq-postgres-dev --region eu-central-1
```

