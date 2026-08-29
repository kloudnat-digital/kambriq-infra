# Terraform native tests for the RDS module.
# Uses mock_provider so no real AWS resources are created.
# Run: terraform test  (from modules/rds-postgres/)

mock_provider "aws" {}

variables {
  env               = "test"
  db_password       = "test-password-placeholder"
  vpc_id            = "vpc-00000000000000000"
  subnet_ids        = ["subnet-00000000000000001", "subnet-00000000000000002"]
  security_group_id = "sg-00000000000000000"
}

run "multi_az_disabled_by_default" {
  command = plan

  assert {
    condition     = var.multi_az == false
    error_message = "multi_az must default to false (only enabled for prd)"
  }
}

run "backup_retention_defaults_to_7_days" {
  command = plan

  assert {
    condition     = var.backup_retention_period == 7
    error_message = "backup_retention_period must default to 7 days"
  }
}

run "storage_is_encrypted" {
  command = plan

  assert {
    condition     = aws_db_instance.main.storage_encrypted == true
    error_message = "RDS storage must always be encrypted"
  }
}

run "not_publicly_accessible" {
  command = plan

  assert {
    condition     = aws_db_instance.main.publicly_accessible == false
    error_message = "RDS must never be publicly accessible"
  }
}

run "skip_final_snapshot_true_by_default" {
  command = plan

  assert {
    condition     = var.skip_final_snapshot == true
    error_message = "skip_final_snapshot must default to true (safe for non-prd)"
  }
}

run "engine_version_is_pinned_and_auto_upgrade_is_off" {
  command = plan

  assert {
    condition     = var.auto_minor_version_upgrade == false
    error_message = "auto_minor_version_upgrade must be off, otherwise AWS moves the minor and the pinned engine_version becomes a downgrade Terraform cannot apply"
  }

  assert {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.engine_version))
    error_message = "engine_version must be a full major.minor version, not a prefix: prefix matching does not suppress the diff on the aws 5.x provider that envs/dev pins"
  }
}
