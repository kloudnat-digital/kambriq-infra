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

# D15 - no NAT gateway on this VPC.
#
# The Fargate tasks moved into the public subnets with public IPs, so nothing in
# the private subnets needs outbound internet any more: only RDS and ElastiCache
# remain there and neither makes an outbound call. The gateway was the largest
# single line in the dev bill, larger than the Fargate compute it served.
#
# Set back to true to restore it. That path is planned, not assumed: with this
# true the plan against the current infrastructure is a strict no-op.
enable_nat_gateway = false
