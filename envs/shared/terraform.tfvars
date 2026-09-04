aws_region        = "eu-central-1"
env               = "shared"
github_repo_infra = "kloudnat-digital/kambriq-infra"

domain_name     = "kambriq.com"
route53_zone_id = "Z00411721R2YKO3VFIPU4"

api_acm_certificate_arn        = "arn:aws:acm:eu-central-1:051551940370:certificate/6f8bbf35-3058-4083-a8dd-f393d5012300"
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/XXXXXXXX"

ses_domain_identity_arn = "arn:aws:ses:eu-central-1:051551940370:identity/kambriq.com"
ses_from_email          = "noreply@kambriq.com"

nat_per_az = false
