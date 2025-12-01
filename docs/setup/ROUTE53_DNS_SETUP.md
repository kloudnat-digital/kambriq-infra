# Configuration DNS Route53 – KAMBRIQ

Ce guide explique comment créer la Route53 hosted zone manuellement et configurer les nameservers pour que la validation DNS (SES, ACM) fonctionne correctement.

## 1. Prérequis

- Vous devez avoir accès au registraire de domaine (où `kambriq.com` est enregistré)
- Accès à la console AWS Route53

## 2. Créer la Route53 Hosted Zone manuellement

**⚠️ IMPORTANT** : La Route53 hosted zone est créée **manuellement** dans AWS Console, pas par Terraform.

### Étapes

1. **Connectez-vous à la console AWS Route53**
2. **Allez dans "Hosted zones"** → **"Create hosted zone"**
3. **Configurez la zone** :
   - **Domain name** : `kambriq.com`
   - **Type** : Public hosted zone
4. **Cliquez sur "Create hosted zone"**
5. **Notez le Zone ID** (ex: `Z035969434MOMAYZATZ1D`) - vous en aurez besoin pour Terraform
6. **Notez les 4 nameservers** affichés (ex: `ns-1104.awsdns-10.org`, etc.)

### Ajouter le Zone ID dans Terraform

Après avoir créé la zone manuellement, ajoutez le `zone_id` dans `envs/shared/terraform.tfvars` :

```hcl
# Route53 hosted zone ID (créé manuellement dans AWS Console)
route53_zone_id = "Z035969434MOMAYZATZ1D"
```

## 3. Récupérer les nameservers Route53

Après avoir créé la zone manuellement, récupérez les nameservers depuis la console AWS ou via AWS CLI :

```bash
# Via AWS CLI
aws route53 get-hosted-zone --id Z035969434MOMAYZATZ1D --query 'DelegationSet.NameServers' --output text

# Ou depuis la console AWS Route53 → Hosted zones → kambriq.com → View details
```

Exemple de sortie :
```
route53_name_servers = [
  "ns-1234.awsdns-12.com",
  "ns-5678.awsdns-34.net",
  "ns-9012.awsdns-56.org",
  "ns-3456.awsdns-78.co.uk"
]
```

## 3. Configurer les nameservers dans votre registraire

### Étapes générales

1. **Connectez-vous à votre registraire de domaine** (ex: GoDaddy, Namecheap, OVH, etc.)
2. **Trouvez la section DNS / Nameservers** pour `kambriq.com`
3. **Remplacez les nameservers actuels** par ceux fournis par Route53
4. **Sauvegardez les modifications**

### Exemples par registraire

#### GoDaddy
1. Allez dans "My Products" → "DNS" → "kambriq.com"
2. Cliquez sur "Change" dans la section "Nameservers"
3. Sélectionnez "Custom" et entrez les 4 nameservers Route53
4. Sauvegardez

#### Namecheap
1. Allez dans "Domain List" → "Manage" pour `kambriq.com`
2. Section "Nameservers" → "Custom DNS"
3. Entrez les 4 nameservers Route53
4. Sauvegardez

#### OVH
1. Allez dans "Domaines" → "kambriq.com" → "Serveurs DNS"
2. Cliquez sur "Modifier" et sélectionnez "Personnalisé"
3. Entrez les 4 nameservers Route53
4. Validez

## 4. Vérifier la propagation DNS

La propagation DNS peut prendre de quelques minutes à 48 heures (généralement 15-30 minutes).

### Vérification avec `dig`

```bash
# Vérifier les nameservers
dig NS kambriq.com

# Vérifier la zone Route53
dig @ns-1234.awsdns-12.com kambriq.com
```

### Vérification avec `nslookup`

```bash
nslookup -type=NS kambriq.com
```

### Vérification en ligne

- [whatsmydns.net](https://www.whatsmydns.net/#NS/kambriq.com)
- [dnschecker.org](https://dnschecker.org/#NS/kambriq.com)

## 5. Relancer Terraform après la propagation

Une fois que les nameservers sont propagés, relancez `terraform apply` :

```bash
cd envs/shared
terraform apply
```

Les validations SES et ACM devraient maintenant réussir car :
- Les enregistrements DNS sont créés automatiquement dans Route53
- Les nameservers pointent vers Route53
- AWS peut vérifier les enregistrements DNS

## 6. Enregistrements DNS créés automatiquement

Une fois les nameservers configurés, Terraform crée automatiquement :

### SES Domain Verification
- **Type** : TXT
- **Nom** : `_amazonses.kambriq.com`
- **Valeur** : Token de vérification SES

### ACM Certificate Validation
- **Type** : CNAME
- **Nom** : `_*.kambriq.com` (wildcard)
- **Valeur** : Token de validation ACM

Ces enregistrements sont créés automatiquement par Terraform dans la zone Route53.

## 7. Dépannage

### Erreur : "timeout while waiting for state to become 'ISSUED'"

**Cause** : Les nameservers ne sont pas encore propagés ou configurés.

**Solution** :
1. Vérifiez que les nameservers sont correctement configurés dans votre registraire
2. Attendez la propagation DNS (peut prendre jusqu'à 48h, généralement 15-30min)
3. Vérifiez avec `dig` ou un outil en ligne
4. Relancez `terraform apply`

### Erreur : "creating SES Domain Identity Verification: output = Pending"

**Cause** : L'enregistrement TXT `_amazonses.kambriq.com` n'est pas accessible.

**Solution** :
1. Vérifiez que les nameservers Route53 sont configurés
2. Vérifiez que l'enregistrement TXT existe dans Route53 :
   ```bash
   aws route53 list-resource-record-sets \
     --hosted-zone-id $(terraform output -raw route53_zone_id) \
     --query "ResourceRecordSets[?Name=='_amazonses.kambriq.com.']"
   ```
3. Attendez la propagation DNS
4. Relancez `terraform apply`

### Vérifier les enregistrements Route53

```bash
# Récupérer la zone ID
ZONE_ID=$(cd envs/shared && terraform output -raw route53_zone_id)

# Lister tous les enregistrements
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID

# Vérifier l'enregistrement SES
aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?contains(Name, '_amazonses')]"
```

## 8. Commandes utiles

```bash
# Afficher tous les outputs Route53
cd envs/shared
terraform output | grep route53

# Afficher uniquement les nameservers (format lisible)
terraform output -json route53_name_servers | jq -r '.[]'

# Afficher la zone ID
terraform output -raw route53_zone_id

# Vérifier l'état de la zone Route53
aws route53 get-hosted-zone --id $(terraform output -raw route53_zone_id)
```

## 9. Notes importantes

- ⚠️ **La Route53 hosted zone est créée manuellement** dans AWS Console, pas par Terraform
- ✅ **Terraform utilise un data source** pour référencer la zone existante via `route53_zone_id`
- ✅ **Une fois les nameservers configurés, tous les enregistrements DNS sont automatiques**
- ⏱️ **La propagation DNS peut prendre du temps** - soyez patient avant de relancer Terraform

