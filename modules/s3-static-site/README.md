# ⚠️ LEGACY MODULE - No longer used

This module is **OBSOLETE** and has been replaced by `modules/frontend/`.

## Migration

The `s3-static-site` module was used for static Next.js export deployment (S3 + CloudFront).

**New approach:** Use `modules/frontend/` which handles:
- S3 bucket for static assets (OpenNext)
- CloudFront distribution
- Lambda functions for SSR (OpenNext)
- OpenNext bundle management

## Status

- ❌ **Not used** in `envs/dev/main.tf` or `envs/prod/main.tf`
- ✅ **Replaced by** `modules/frontend/`
- 📅 **Deprecated since:** Migration to OpenNext + Lambda SSR

## Action

This module can be moved to `legacy/modules/` or deleted after confirming no other references exist.
