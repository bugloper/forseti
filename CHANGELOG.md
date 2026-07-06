# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Phase 1 — Scanner & Reporting (ADR 001): 13 built-in configuration-posture
  checks, `Forseti::Scanner::Check` base class for custom checks, severity
  model, error-isolated runner, and environment-honest skipping.
- Rake tasks: `forseti:doctor` (scored TTY report, CI exit code via
  `config.scanner.fail_on`), `forseti:score`, `forseti:report` (versioned JSON
  schema), and `forseti:checks`.
- Transparent scoring (severity-weighted, skipped/errored checks excluded,
  per-category subscores) with A–F grades.

- Phase 0 skeleton: gem structure, Zeitwerk loading, inert Rails engine.
- Configuration system: `Forseti.configure`, validated per-module configuration
  classes (`Forseti::Config::Base`), versioned defaults
  (`config.defaults = "1.0"`), and `enable!`/`disable!` semantics.
- Test harness: RSpec with an Active-Record-free dummy app, Appraisal matrix
  (Rails 7.1 / 7.2 / 8.0), GitHub Actions CI, RuboCop.
- ADR 000 (docs/design/000-foundations.md) recording the foundational
  architecture decisions.
