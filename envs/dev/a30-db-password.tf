# ============================================================================
# A30 - the RDS master password, generated rather than written down.
# ============================================================================
#
# Until this file existed, `envs/dev/terraform.tfvars` carried
# `db_password = "CHANGE_ME"` and that nine-character string was the live master
# password of the dev database. Not a placeholder that had been superseded: the
# live value. The README and docs/deployment-sequence.md both instruct the
# operator to `export TF_VAR_db_password=...` before applying, but
# `.github/workflows/terraform-apply.yml` passes no `-var` and sets no `TF_VAR_`,
# so every apply since February wrote the placeholder back. The documentation
# described a discipline nothing enforced, which is the most expensive kind.
#
# The fix is the pattern this repository already chose for NEXTAUTH_SECRET:
# generate the value, keep it out of the repository entirely, and then tell
# Terraform to stop looking at it.
#
# ORDER MATTERS, AND IT IS COUNTER-INTUITIVE
#
# `ignore_changes = [password]` and the new value cannot land in the same apply.
# On an existing resource Terraform would see the ignore rule first, decline to
# compare, and leave CHANGE_ME in place while reporting success. So this file
# lands first, alone, and rotates. The ignore rule follows in a second apply,
# once the new value is the one in state.
#
# WHY `special = false`
#
# `modules/ssm-app-parameters/main.tf` composes the four DATABASE_URL_*
# parameters by raw string interpolation:
#
#     postgresql://${db_username}:${db_password}@${db_host}:${db_port}/...
#
# There is no URL-encoding anywhere in that path. A `#` truncates the URL, a `%`
# opens a percent-escape, `&` and `?` are read as query syntax, and `@` breaks
# the host apart. The NextAuth generator two files over uses
# `override_special = "!#$%&*()-_=+[]{}<>:?"`, which is safe for a value carried
# in an environment variable and would be quietly catastrophic here. Thirty-two
# alphanumeric characters carry roughly 190 bits, which is more than enough, and
# removes the encoding question rather than answering it.
resource "random_password" "db_master" {
  length  = 32
  special = false
}
