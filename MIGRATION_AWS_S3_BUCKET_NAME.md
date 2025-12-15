# Migration : S3_MEDIA_BUCKET → AWS_S3_BUCKET_NAME

## Objectif
Unifier le nom de la variable d'environnement Lambda pour le bucket S3 :
- **Ancien nom** : `S3_MEDIA_BUCKET` (défini par Terraform)
- **Nouveau nom** : `AWS_S3_BUCKET_NAME` (utilisé par l'application)

## Impact
⚠️ **IMPORTANT** : Cette modification nécessitera la **recréation de la ressource Lambda** car les variables d'environnement sont modifiées.

### Ressources affectées
- `aws_lambda_function.main` dans `modules/lambda-api/main.tf`
  - **Action** : Terraform détruira et recréera la fonction Lambda
  - **Durée d'indisponibilité** : ~1-2 minutes pendant la recréation
  - **Données** : Aucune perte (la fonction est recréée avec la même configuration)

## Changements proposés

### 1. Module Lambda API (`modules/lambda-api/main.tf`)

**Ligne 42** : Changer la variable d'environnement Lambda

```diff
  environment {
    variables = {
      NODE_ENV        = var.env
      DB_HOST         = var.db_host
      DB_PORT         = tostring(var.db_port)
      DB_NAME         = var.db_name
      DB_USERNAME     = var.db_username
      DB_PASSWORD     = var.db_password
-     S3_MEDIA_BUCKET = var.s3_media_bucket
+     AWS_S3_BUCKET_NAME = var.s3_media_bucket
      SES_FROM_EMAIL  = var.ses_from_email
      JWT_SECRET      = var.jwt_secret
    }
  }
```

### 2. Application (`kambriq/api/src/infrastructure/config/config-loader.ts`)

**Supprimer le mapping** ajouté précédemment (lignes 59-68)

```diff
  // Map SES_FROM_EMAIL to AWS_SES_FROM_EMAIL for SES service compatibility
  if (config.SES_FROM_EMAIL) {
    process.env.AWS_SES_FROM_EMAIL = config.SES_FROM_EMAIL;
  }

- // Map S3_MEDIA_BUCKET (from Terraform Lambda env vars) to AWS_S3_BUCKET_NAME (expected by S3 service)
- // This allows compatibility between Terraform configuration and application code
- // Check both SSM config and direct process.env (Terraform sets it as Lambda env var)
- if (!process.env.AWS_S3_BUCKET_NAME) {
-   if (config.AWS_S3_BUCKET_NAME) {
-     process.env.AWS_S3_BUCKET_NAME = config.AWS_S3_BUCKET_NAME;
-   } else if (process.env.S3_MEDIA_BUCKET) {
-     process.env.AWS_S3_BUCKET_NAME = process.env.S3_MEDIA_BUCKET;
-   }
- }
```

## Plan d'exécution

### Étape 1 : Modifier Terraform
1. Modifier `modules/lambda-api/main.tf` (ligne 42)
2. Commiter et pousser les changements

### Étape 2 : Appliquer Terraform
```bash
# Pour DEV
cd kambriq-aws-iac-terraform/envs/dev
terraform plan  # Vérifier que seule la Lambda sera recréée
terraform apply # Appliquer les changements

# Pour PROD (après validation en DEV)
cd kambriq-aws-iac-terraform/envs/prod
terraform plan
terraform apply
```

### Étape 3 : Supprimer le mapping dans l'application
1. Modifier `kambriq/api/src/infrastructure/config/config-loader.ts`
2. Supprimer le code de mapping (lignes 59-68)
3. Commiter et pousser
4. Redéployer l'application (le workflow GitHub Actions le fera automatiquement)

## Vérifications post-migration

### 1. Vérifier la variable d'environnement Lambda
```bash
aws lambda get-function-configuration \
  --function-name kambriq-api-dev \
  --query 'Environment.Variables.AWS_S3_BUCKET_NAME' \
  --output text
```

### 2. Tester l'application
- Vérifier que l'application démarre correctement
- Tester une opération S3 (upload de fichier)

## Fichiers à modifier

### Terraform (1 fichier)
- `kambriq-aws-iac-terraform/modules/lambda-api/main.tf` (ligne 42)

### Application (1 fichier)
- `kambriq/api/src/infrastructure/config/config-loader.ts` (supprimer lignes 59-68)

## Notes importantes

1. **Pas de changement de variable Terraform** : La variable `s3_media_bucket` dans `modules/lambda-api/variables.tf` reste inchangée. Seule la variable d'environnement Lambda change.

2. **Pas d'impact sur les autres ressources** : Seule la fonction Lambda est affectée. Les buckets S3, IAM roles, etc. ne changent pas.

3. **Rollback possible** : En cas de problème, on peut revenir en arrière en changeant `AWS_S3_BUCKET_NAME` → `S3_MEDIA_BUCKET` dans Terraform et en réappliquant.

## Validation requise

- [ ] Valider le changement dans `modules/lambda-api/main.tf`
- [ ] Valider la suppression du mapping dans `config-loader.ts`
- [ ] Valider le plan d'exécution (DEV puis PROD)
- [ ] Valider la durée d'indisponibilité acceptée (~1-2 min)
