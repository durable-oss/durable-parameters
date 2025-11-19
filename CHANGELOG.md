# Changelog

All notable changes to Durable Parameters will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CONTRIBUTING.md with comprehensive contribution guidelines
- SECURITY.md with security reporting and best practices
- CHANGELOG.md to track version history
- Enhanced documentation for PERMITTED_SCALAR_TYPES constant

### Changed
- Improved inline documentation throughout codebase

### Fixed
- N/A

## [1.0.0] - [Date TBD]

### Added
- Framework-agnostic core module (`StrongParameters::Core`)
- `Parameters` class with declarative parameter filtering
- `ApplicationParams` class with DSL for permission definitions
- `ParamsRegistry` for centralized params class management
- `ForbiddenAttributesProtection` mixin for mass assignment protection
- Rails adapter with full ActionController and ActiveModel integration
- Sinatra adapter with `strong_params` helper
- Hanami adapter supporting both 1.x and 2.x
- Rage adapter with Rails-compatible API
- Auto-detection of frameworks
- Comprehensive YARD documentation
- Action-specific parameter permissions (`:only`, `:except`)
- Parameter transformations with metadata support
- Metadata declaration system with validation
- Inheritance support for params classes
- Custom flags for application-specific logic
- Array attribute support with `array: true` option

### Changed
- Refactored from Rails-only to framework-agnostic architecture
- Moved Rails-specific code to adapter pattern
- Improved error messages with actionable guidance
- Enhanced performance with permission caching

### Deprecated
- `permit_by_model` method (use `transform_params` instead)

### Security
- Explicit whitelisting required for all parameters
- Unpermitted parameters can be logged or raise exceptions
- Mass assignment protection by default
- Metadata key validation prevents injection attacks

## [0.x] - Legacy Versions

Previous versions were Rails-specific. See git history for details.

---

[Unreleased]: https://github.com/durableprogramming/durable_parameters/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/durableprogramming/durable_parameters/releases/tag/v1.0.0
