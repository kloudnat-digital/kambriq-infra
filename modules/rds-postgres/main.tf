# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "kambriq-db-subnet-${var.env}"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "kambriq-db-subnet-${var.env}"
    Env  = var.env
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "kambriq-postgres-${var.env}"
  family = "postgres15"

  tags = {
    Name = "kambriq-postgres-${var.env}"
    Env  = var.env
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "kambriq-postgres-${var.env}"

  engine = "postgres"
  # Pinned in full, with auto minor upgrades off, so the declared version and the
  # running version cannot diverge. An upgrade is a deliberate bump of this value.
  engine_version             = var.engine_version
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  instance_class             = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true
  db_name           = var.db_name
  username          = var.db_username
  # A30. The value reaching this argument is generated (`random_password`) and
  # exists in exactly two places: the Terraform state, and SSM. It is
  # deliberately not in the repository, and `ignore_changes` below is what keeps
  # it that way - see the lifecycle block for why the two had to land in
  # separate applies.
  password = var.db_password

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "kambriq-postgres-${var.env}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  lifecycle {
    # A30. Terraform sets this password once and then stops looking at it.
    #
    # RDS never returns a password, so Terraform cannot detect drift here and
    # has only its own state to compare against. Before A30 that state said
    # a nine-character placeholder, because `envs/dev/terraform.tfvars` said
    # so and
    # `terraform-apply.yml` passes no `-var` - so every apply rewrote the
    # placeholder back as the live master password, for seven months, reporting
    # success each time.
    #
    # WHY THIS COULD NOT SHIP WITH THE ROTATION
    #
    # On an existing instance, adding this rule in the same change as the new
    # value does nothing at all: Terraform reads the rule first, declines to
    # compare, and leaves the old password in place while the plan and the apply
    # both come out clean. The rotation therefore landed alone, and this
    # followed once the generated value was the one in state.
    #
    # THE ONE WAY THIS CAN STILL BREAK
    #
    # `random_password.db_master` in `envs/dev` is the sole record of the value
    # outside SSM. If that resource is ever tainted, removed from state or
    # replaced, it regenerates - and because of this rule the new value would be
    # written into the four DATABASE_URL_* parameters while the instance kept
    # the old one, taking the environment down with a green apply. Rotate by
    # replacing `random_password` and removing this rule for one apply, in that
    # order, never by tainting it.
    ignore_changes = [password]
  }

  publicly_accessible = false
  multi_az            = var.multi_az

  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? ["postgresql", "upgrade"] : []

  tags = {
    Name = "kambriq-postgres-${var.env}"
    Env  = var.env
  }

  # To enable destroy protection on an existing prd instance, uncomment below.
  # prevent_destroy cannot be set dynamically in Terraform — enable manually
  # in the prd workspace after first apply.
  #
  # lifecycle {
  #   prevent_destroy = true
  # }
}
