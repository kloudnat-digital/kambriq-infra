# Utilisation de l'Auto Scaling Group (ASG) pour le Bastion

## Avantages de l'ASG

✅ **Arrêt simple** : Passer (min, desired, max) à (0, 0, 0) au lieu d'utiliser une Lambda  
✅ **Mise à jour facile** : Modifier le Launch Template user-data et forcer un refresh  
✅ **Moins de ressources** : Pas besoin de Lambda + EventBridge  
✅ **Standard AWS** : ASG est la pratique recommandée pour ce cas d'usage  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BASTION AVEC ASG                          │
└─────────────────────────────────────────────────────────────┘

Elastic IP (EIP)
    │
    ▼
┌──────────────────────┐
│ Auto Scaling Group   │
│ (min=1, desired=1, max=1) │
└──────────────────────┘
    │
    ▼
┌──────────────────────┐
│ Launch Template      │
│ - AMI Ubuntu 22.04   │
│ - User-data (setup)  │
│ - IAM Role (EIP)     │
└──────────────────────┘
    │
    ▼
┌──────────────────────┐
│ EC2 Instance         │
│ (créée par ASG)      │
│ - Associe EIP auto   │
└──────────────────────┘
```

## Gestion du Bastion

### Arrêter le Bastion

**Via Terraform** :
```hcl
# Dans envs/shared/terraform.tfvars
asg_min_size = 0
asg_desired_size = 0
asg_max_size = 0
```

Puis :
```bash
cd envs/shared
terraform apply
```

**Via AWS CLI** :
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name kambriq-bastion-shared \
  --desired-capacity 0 \
  --region eu-central-1
```

**Via Terraform Output** :
```bash
cd envs/shared
terraform output bastion_stop_command | bash
```

### Démarrer le Bastion

**Via Terraform** :
```hcl
# Dans envs/shared/terraform.tfvars
asg_min_size = 1
asg_desired_size = 1
asg_max_size = 1
```

Puis :
```bash
cd envs/shared
terraform apply
```

**Via AWS CLI** :
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name kambriq-bastion-shared \
  --desired-capacity 1 \
  --region eu-central-1
```

**Via Terraform Output** :
```bash
cd envs/shared
terraform output bastion_start_command | bash
```

### Mettre à Jour le User-Data

Quand vous modifiez le `user_data` dans le Launch Template, l'ASG ne met pas automatiquement à jour les instances existantes. Vous devez forcer un refresh :

**Via AWS CLI** :
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name kambriq-bastion-shared \
  --region eu-central-1
```

**Via Terraform Output** :
```bash
cd envs/shared
terraform output bastion_refresh_command | bash
```

**Via Terraform** :
```bash
# Taint le Launch Template pour forcer la recréation
cd envs/shared
terraform taint module.bastion[0].aws_launch_template.bastion
terraform apply
```

## Workflow Complet

### 1. Modifier le User-Data

Éditer `modules/bastion/main.tf` et modifier la section `user_data` dans `aws_launch_template.bastion`.

### 2. Appliquer les Changements

```bash
cd envs/shared
terraform plan  # Vérifier les changements
terraform apply
```

### 3. Forcer le Refresh de l'ASG

```bash
# Option 1: Via AWS CLI
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name $(terraform output -raw bastion_asg_name) \
  --region eu-central-1

# Option 2: Via Terraform output
terraform output bastion_refresh_command | bash
```

L'ASG va :
1. Créer une nouvelle instance avec le nouveau user-data
2. Attendre que la nouvelle instance soit healthy
3. Terminer l'ancienne instance
4. L'EIP sera automatiquement associée à la nouvelle instance (via user-data)

## Vérification

### Vérifier l'État de l'ASG

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names kambriq-bastion-shared \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].InstanceId]' \
  --output table
```

### Vérifier l'Instance

```bash
# Récupérer l'instance ID depuis l'ASG
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names kambriq-bastion-shared \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

# Vérifier l'état
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]' \
  --output table
```

### Vérifier l'Association EIP

```bash
# Vérifier que l'EIP est bien associée
aws ec2 describe-addresses \
  --filters "Name=tag:Name,Values=kambriq-bastion-shared-eip" \
  --query 'Addresses[0].[PublicIp,InstanceId]' \
  --output table
```

## Notes Importantes

- ⚠️ **EIP Association** : L'EIP est associée automatiquement via user-data au démarrage de l'instance
- ⚠️ **Instance Refresh** : Après modification du user-data, forcer un refresh pour appliquer les changements
- ✅ **IP Fixe** : L'EIP reste la même après refresh (associée automatiquement)
- ✅ **Pas de Lambda** : Plus besoin de Lambda auto-stop, tout se gère via ASG capacity

## Comparaison avec l'Ancienne Approche

| Aspect | Ancienne (EC2 + Lambda) | Nouvelle (ASG) |
|--------|------------------------|----------------|
| Arrêt | Lambda + EventBridge | ASG capacity = 0 |
| Mise à jour user-data | Recréer instance manuellement | Refresh ASG |
| Complexité | Lambda + EventBridge + IAM | ASG uniquement |
| Coûts | Lambda + EventBridge | ASG (gratuit) |
| Maintenance | Plus complexe | Plus simple |
