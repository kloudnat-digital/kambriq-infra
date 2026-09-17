# ---------------------------------------------------------------------------
# D20 - the Redis AUTH token, generated here and never written down.
#
# THE FACT THIS ANSWERS. `redis_auth_token = ""` in terraform.tfvars, and that
# is the live value: `describe-replication-groups` reads `AuthTokenEnabled:
# false`, `TransitEncryptionEnabled: false` on kambriq-dev-redis (redis 7.1.0,
# cluster mode disabled, at-rest encryption on). No password at all. Anyone who
# reaches the VPC reaches the session store and the five queues - KBS, CORE,
# KAMNET, NOTIFICATIONS, DUNNING - and since D1 that is the VPC production will
# also live in, which is why this is on the ISO list rather than a dev nicety.
#
# WHY A GENERATED VALUE, and not a variable somebody fills in. A token in
# terraform.tfvars is a secret in the repository, and a token passed with -var
# is a value the apply never sees (D15 learned that the hard way). `random_password`
# keeps it in the state - where the database master password already lives since
# A30 - and puts it in SSM as a SecureString for the task to read. The value is
# never rendered: it is marked sensitive end to end, and the acceptance for this
# chantier compares booleans, never the token.
#
# THE CHARACTER SET IS NOT COSMETIC. AWS: tokens "must be 16-128 printable
# characters" and "nonalphanumeric characters are restricted to (!, &, #, $, ^,
# <, >, -)". A generated password containing anything else is refused by
# ElastiCache at modify time, which is a failed apply rather than a clear error.
# 48 characters from that alphabet is far past the 16 minimum.
#
# ROTATION. Changing this resource's `keepers` is how the token is rotated
# deliberately; the module's `auth_token_update_strategy` decides whether the
# cluster keeps accepting the previous one while clients catch up. Nothing
# rotates it automatically, and pretending otherwise would be worse than saying
# so: ElastiCache AUTH has no managed rotation, which is why AWS now points at
# RBAC with Secrets Manager for that. Recorded, not solved here.
# ---------------------------------------------------------------------------

resource "random_password" "redis_auth_token" {
  length = 48

  # Printable, and only the eight non-alphanumerics ElastiCache accepts.
  override_special = "!&#$^<>-"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}
