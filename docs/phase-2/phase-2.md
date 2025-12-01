A) Exposer api.kambriq.com directement vs passer par CloudFront
A.1 Deux options possibles

Option actuelle (ce qu’on a designé)

Le navigateur appelle https://kambriq.com (ou dev.kambriq.com).

CloudFront reçoit toutes les requêtes.

CloudFront :

sert le frontend statique depuis S3,

route /api/* vers API Gateway HTTP API (qui déclenche les Lambdas).

Option alternative : api.kambriq.com direct

https://kambriq.com → CloudFront → S3 (front uniquement).

https://api.kambriq.com → directement sur API Gateway (Custom domain).

Il faut alors :

un certificat ACM us-east-1 pour CloudFront (front),

un certificat ACM eu-central-1 pour api.kambriq.com (API Gateway prod),

et idem pour api.dev.kambriq.com côté dev.

A.2 Impact performance

Avec CloudFront devant l’API :

+1 hop : Client → CloudFront → API Gateway.

Mais :

TLS terminé au plus proche de l’utilisateur (edge).

Connexion réutilisée / HTTP/2.

Possibilité de cacher certaines réponses API (ex : config publique, listes peu changeantes).

Possibilité de compresser / optimiser (headers, etc.).

API directe (api.kambriq.com) :

Chemin plus simple : Client → API Gateway.

Légèrement moins de latence théorique (quelques millisecondes de moins).

Mais :

pas de cache edge,

TLS directement dans la région eu-central-1.

👉 Pour un MVP avec trafic “normal”, la différence de perf est quasi négligeable. CloudFront n’est pas “lent”, surtout depuis l’Europe vers eu-central-1.

A.3 Impact coûts

Avec CloudFront devant l’API :

Tu payes :

requêtes CloudFront + sortie data CloudFront,

requêtes API Gateway + exécutions Lambda.

En gros, tu as un service de plus facturé.

API directe :

Tu supprimes le coût CF pour le trafic API (mais pas pour le front).

À petit / moyen trafic :

l’économie est assez faible (quelques euros par mois).

À très gros volume API :

ça peut devenir significatif.

Pour un MVP, l’enjeu coût est honnêtement secondaire par rapport à la simplicité / clarté de l’architecture.

A.4 Différences fonctionnelles

CloudFront devant l’API te donne :

Un seul point d’entrée (même domaine que le front) :

ex. /api/* sur kambriq.com et dev.kambriq.com.

Possibilité d’ajouter facilement :

WAF, protection DDoS,

règles de routing avancées,

CDN / caching pour certaines routes.

Uniformité côté navigateur :

pas de CORS exotique, mêmes cookies, même domaine.

API directe (api.kambriq.com) :

Architecture plus simple côté AWS (un service de moins dans la chaîne).

Domaines séparés front / API (ce qui peut être plus clair pour certains clients d’API tiers).

Nécessite plus de gestion CORS côté front (kambriq.com appelant api.kambriq.com).

A.5 Recommandation pour KAMBRIQ (MVP)

Vu :

que tu as déjà SES + Route 53 + CF à gérer,

que CloudFront est de toute façon nécessaire pour le frontend,

que tu as un MVP à sortir, pas une infra multi-tenant ultra-optimisée,

👉 Je recommande de garder l’option actuelle : API derrière CloudFront, et de ne PAS ajouter api.kambriq.com maintenant.

On documente api.kambriq.com comme option Phase 2 (tout est prêt conceptuellement, on sait ce qu’il faut faire), mais on évite de complexifier Terraform tout de suite.

A.6 Si plus tard tu adoptes api.kambriq.com, qu’est-ce qu’on change ? (Phase 2)
1. Mises à jour d’architecture (logique + infra)

Vue logique (phase 2) :

Navigateur / Mobile
   │
   ├─ https://kambriq.com → CloudFront → S3 (frontend)
   │
   └─ https://api.kambriq.com → API Gateway HTTP API → Lambda (NestJS) → RDS / S3 / SES


Vue infra/TF (phase 2) :

Ajout, par environnement, de :

aws_api_gateway_domain_name (ou équivalent HTTP API),

aws_api_gateway_base_path_mapping,

aws_acm_certificate en eu-central-1 pour :

prod : api.kambriq.com,

dev : api.dev.kambriq.com.

Ajout de records Route 53 :

api.kambriq.com → alias / CNAME vers le target donné par API Gateway,

api.dev.kambriq.com idem.

2. Prompt Cursor “Phase 2 – Ajouter api.kambriq.com direct” (à garder pour plus tard)

⚠️ À ne pas lancer maintenant, à garder dans ta doc Phase 2.
--------------------------------------------------------------------------------------------------------------------
Tu es dans le dossier `~/workspace/kambriq-aws-iac-terraform`.

Objectif Phase 2 (NE PAS APPLIQUER SI L’ARCHITECTURE N’EST PAS ENCORE PRÊTE) :
Ajouter un domaine custom `api.kambriq.com` (prod) et `api.dev.kambriq.com` (dev) qui pointent directement vers API Gateway HTTP API, sans passer par CloudFront, tout en conservant CloudFront pour le frontend.

Tâches :

1. Cartographie actuelle
   - Lister les ressources suivantes dans le code Terraform :
     - CloudFront distributions (prod + dev),
     - API Gateway HTTP API (prod + dev),
     - Route 53 zone `kambriq.com`,
     - éventuels `aws_acm_certificate` déjà définis.
   - Résumer dans un commentaire en haut du fichier principal (ou dans `docs/integration/APP_INTEGRATION.md`) la chaîne actuelle :
     - Domaines → CloudFront → API Gateway.

2. Variables à introduire (sans encore les utiliser si ce n’est pas le bon moment) :
   - Dans le module / stack API :
     - `api_custom_domain_name` (string),
     - `api_acm_certificate_arn` (string, région eu-central-1),
     - `api_enable_custom_domain` (bool, default = false).
   - Préparer aussi les variables env-level (dev/prod) correspondantes.

3. Ressources à prévoir (en gardant `count = api_enable_custom_domain ? 1 : 0`) :
   - Ressource `aws_apigatewayv2_domain_name` (pour HTTP API) ou équivalent approprié.
   - `aws_apigatewayv2_api_mapping` pour mapper `/` vers le stage principal de l’API.
   - Ressource Route 53 `aws_route53_record` :
     - `api.${var.root_domain}` pour prod,
     - `api.dev.${var.root_domain}` pour dev,
     - type ALIAS / CNAME vers le target de `aws_apigatewayv2_domain_name`.
   - Utiliser `api_acm_certificate_arn` (certificat créé manuellement en eu-central-1) dans la définition du domain name.

4. Documentation :
   - Dans `docs/integration/APP_INTEGRATION.md`, ajouter une section “Phase 2 – Domaine direct API (api.kambriq.com)” qui :
     - décrit la nouvelle chaîne d’appel,
     - explicite que les certificats ACM pour l’API doivent être créés manuellement en eu-central-1, DNS-validés, puis leurs ARN injectés dans les tfvars.

5. Sécurité :
   - Vérifier que les CORS du backend acceptent :
     - origins `https://kambriq.com` et `https://dev.kambriq.com`,
     - et éventuellement `https://api.kambriq.com` si nécessaire.
   - Ne pas modifier CloudFront tant que cette option n’est pas activée.

Ne modifie PAS les tfvars pour l’instant, contente-toi d’ajouter les variables et les ressources avec les `count` conditionnels pour que le plan Terraform reste identique (api_enable_custom_domain = false par défaut).
--------------------------------------------------------------------------------------------------------------------
