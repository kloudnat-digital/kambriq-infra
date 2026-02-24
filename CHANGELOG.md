# Changelog

All notable changes to this project will be documented in this file.
This format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
 - Shared `envs/` structure with `shared`, `dev`, and `prd` stacks.
 - Remote state backends and shared VPC/NAT stack.
 - ElastiCache Redis module and outputs.
 - GitHub variables helper script and docs.
### Changed
 - Align ALB routing and health checks for NestJS API.
 - Update ECS init container defaults to Prisma migrations.
 - Expand SSM parameters to match API runtime config.
 - Standardize environment naming to `dev`/`prd` and use shared state.
### Deprecated
### Removed
### Fixed
### Security

## [0.1.0] - 2026-02-22
### Added
- Initial release.
- Infrastructure as code baseline for AWS.

[Unreleased]: https://github.com/kloudnat-digital/kambriq-infra/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kloudnat-digital/kambriq-infra/releases/tag/v0.1.0
