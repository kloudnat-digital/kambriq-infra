# Terraform native tests for the ALB module.
# Uses mock_provider so no real AWS resources are created.
# Run: terraform test  (from modules/alb/)

mock_provider "aws" {}

variables {
  project_name      = "test"
  env               = "test"
  vpc_id            = "vpc-00000000000000000"
  public_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

run "access_logs_disabled_by_default" {
  command = plan

  assert {
    condition     = var.access_logs_bucket == ""
    error_message = "access_logs_bucket must default to empty string (logging disabled by default)"
  }
}

run "deletion_protection_disabled_by_default" {
  command = plan

  assert {
    condition     = var.enable_deletion_protection == false
    error_message = "enable_deletion_protection must default to false"
  }
}

run "api_port_defaults_to_3000" {
  command = plan

  assert {
    condition     = var.api_port == 3000
    error_message = "api_port must default to 3000"
  }
}

run "web_port_defaults_to_3000" {
  command = plan

  assert {
    condition     = var.web_port == 3000
    error_message = "web_port must default to 3000"
  }
}
