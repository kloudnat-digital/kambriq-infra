# ⚠️ LEGACY MODULE - No longer used

This module is **OBSOLETE** and has been replaced by `modules/frontend/`.

## Migration

The `cloudfront` module was used as a standalone CloudFront distribution module.

**New approach:** Use `modules/frontend/` which handles:
- S3 bucket for static assets (OpenNext)
- CloudFront distribution (integrated)
- Lambda functions for SSR (OpenNext)
- OpenNext bundle management

## Status

- ❌ **Not used** in `envs/dev/main.tf` or `envs/prod/main.tf`
- ✅ **Replaced by** `modules/frontend/`
- 📅 **Deprecated since:** Migration to OpenNext + Lambda SSR

## Action

This module can be moved to `legacy/modules/` or deleted after confirming no other references exist.
