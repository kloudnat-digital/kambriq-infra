# Legacy Code - KAMBRIQ Terraform

This directory contains code and documentation that is no longer used in the active KAMBRIQ infrastructure but is kept for historical reference.

## Contents

### `modules/network/`
- **Status**: LEGACY - No longer used
- **Reason**: Replaced by `modules/shared` which includes VPC/networking functionality
- **Replacement**: Use `modules/shared` for all networking needs

### `modules/ses/`
- **Status**: LEGACY - No longer used
- **Reason**: Replaced by `modules/shared` which includes SES functionality
- **Replacement**: Use `modules/shared` for all SES needs

### `REFACTOR_PLAN.md`
- **Status**: LEGACY - Planning document for completed refactoring
- **Reason**: The refactoring described (shared module, remote_state) has been completed and is in use
- **Note**: This document describes the migration that was already performed

## Active Code

All active infrastructure code is in:
- `envs/shared/`, `envs/dev/`, `envs/prod/` - Active environments
- `modules/shared/`, `modules/rds-postgres/`, `modules/s3-*/`, `modules/cloudfront/`, `modules/iam/`, `modules/lambda-api/`, `modules/api-gateway/` - Active modules

Do not use anything in this `legacy/` directory for new infrastructure.

