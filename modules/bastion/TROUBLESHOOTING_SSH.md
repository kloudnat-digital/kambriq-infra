# Troubleshooting SSH pour GitHub

## Problème : Clone SSH ne fonctionne pas

### Vérification 1 : Tester la connexion SSH à GitHub

Sur le bastion, exécutez :

```bash
ssh -T git@github.com
```

**Résultat attendu** :
```
Hi kisquish! You've successfully authenticated, but GitHub does not provide shell access.
```

**Si erreur** :
- Vérifiez que la clé SSH est bien ajoutée à votre compte GitHub
- Vérifiez les permissions de la clé : `chmod 600 ~/.ssh/id_ed25519`

### Vérification 2 : Vérifier la clé SSH

```bash
# Voir la clé publique
cat ~/.ssh/id_ed25519.pub

# Vérifier les permissions
ls -la ~/.ssh/
# Doit afficher :
# -rw------- id_ed25519 (clé privée)
# -rw-r--r-- id_ed25519.pub (clé publique)
```

### Vérification 3 : Ajouter GitHub au known_hosts

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### Solution Alternative : Utiliser HTTPS avec Personal Access Token

Si SSH continue de poser problème :

```bash
# Créer un Personal Access Token sur GitHub
# Settings → Developer settings → Personal access tokens → Tokens (classic)
# Scopes : repo (full control of private repositories)

# Cloner avec le token
git clone https://<TOKEN>@github.com/kloudnat-digital/kambriq.git

# Ou utiliser une variable d'environnement
export GITHUB_TOKEN="votre_token"
git clone https://${GITHUB_TOKEN}@github.com/kloudnat-digital/kambriq.git
```

## Configuration SSH Recommandée

### 1. Générer une clé SSH sur le bastion

```bash
ssh-keygen -t ed25519 -C "bastion-kambriq-dev" -f ~/.ssh/id_ed25519 -N ""
```

### 2. Afficher la clé publique

```bash
cat ~/.ssh/id_ed25519.pub
```

### 3. Ajouter à GitHub

1. Aller sur GitHub → Settings → SSH and GPG keys
2. Cliquer "New SSH key"
3. Titre : "Bastion DEV"
4. Coller le contenu de `~/.ssh/id_ed25519.pub`
5. Cliquer "Add SSH key"

### 4. Tester la connexion

```bash
ssh -T git@github.com
```

### 5. Cloner le repository

```bash
git clone git@github.com:kloudnat-digital/kambriq.git
```

## Notes Importantes

- ⚠️ **Ne jamais commiter la clé privée** (`~/.ssh/id_ed25519`)
- ✅ La clé publique peut être partagée
- ✅ Chaque bastion (dev/prod) devrait avoir sa propre clé SSH
- ✅ Les clés SSH sont persistantes sur l'instance (même après redémarrage)
