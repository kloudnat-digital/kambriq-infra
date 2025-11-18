# Backend configuration
# Pour l'instant, l'état est stocké localement
# Pour migrer vers S3, décommenter et configurer :

# terraform {
#   backend "s3" {
#     bucket = "kambriq-terraform-state"
#     key    = "prod/terraform.tfstate"
#     region = "eu-west-1"
#     # Optionnel: activer le versioning et le chiffrement
#     # dynamodb_table = "terraform-state-lock"
#     # encrypt        = true
#   }
# }

