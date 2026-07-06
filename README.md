# Forseti

**Security and compliance framework for Ruby on Rails.**

Forseti aims to do for Rails security and privacy what Devise did for
authentication: unify, verify, and extend what Rails already provides behind
one Rails-native, convention-over-configuration framework — security posture
scanning and scoring, security headers, PII detection and redaction, audit
trails, and compliance primitives for GDPR, CCPA, LGPD, and India's DPDP Act.

> **Status: pre-alpha.** Forseti is under active design and development and is
> not yet released. The architecture is documented in
> [docs/design/000-foundations.md](docs/design/000-foundations.md); each
> feature lands with its own design doc before code.

## Principles

- **Observe by default, enforce by opt-in.** Installing the gem changes
  nothing. Every enforcing feature runs in `:off`, `:report`, or `:enforce`
  mode; `enable!` opts into recommended secure defaults.
- **Verify Rails, don't reimplement it.** Wherever a Rails API exists (CSP
  DSL, `filter_parameters`, Active Record encryption, host authorization),
  Forseti configures it, checks it, and reports on it.
- **Versioned defaults.** `config.defaults = "1.0"` pins behavior exactly like
  Rails' `load_defaults` — upgrading the gem never silently changes your app.
- **No monkey patching.** Integration happens through Railtie initializers,
  middleware, `ActiveSupport.on_load` hooks, and opt-in concerns.
- **Compliance evidence, not legal guarantees.** Forseti helps you meet
  regulatory requirements and tracks what it cannot verify as explicit human
  attestations. It does not — and cannot — make you compliant by itself.

## Usage

```bash
bin/rails forseti:doctor   # scored, actionable security posture report
bin/rails forseti:score    # the number your team drives upward
bin/rails forseti:report   # machine-readable JSON for CI
bin/rails forseti:checks   # list every registered check
```

```text
Forseti Doctor — security posture for Shop (production)
Ruby 3.4.2 · Rails 8.0.3 · Forseti 0.1.0

Failures:
  ✖ security.csp                     No Content Security Policy is configured [high]
      ↳ Define a policy in config/initializers/content_security_policy.rb using Rails' built-in DSL.

Passed:
  ✔ security.cookies                 Session cookie settings are hardened
  ✔ security.csrf                    CSRF protection enabled
  ...

Score: 82/100 (B) — 10 passed, 1 failed, 2 skipped
privacy 100 · security 78
```

`forseti:doctor` exits non-zero when a failure is at least `config.scanner.fail_on`
(default `:high`), so it drops straight into CI. Run it with
`RAILS_ENV=production` for full coverage — production-only checks (force_ssl,
HSTS, host authorization) are honestly reported as *skipped*, never as passed,
in other environments.

Reports describe what protections are *missing* — treat CI artifacts containing
them as sensitive. They never contain secret values, only presence or absence.

```ruby
# config/initializers/forseti.rb
Forseti.configure do |config|
  config.defaults = "1.0"
  config.scanner.skip_checks = ["security.csp_nonce"]
  config.scanner.fail_on = :critical
end

# Ship your own checks:
class InternalAuthCheck < Forseti::Scanner::Check
  id          "custom.internal_auth"
  severity    :high
  title       "Internal admin requires SSO"
  remediation "Mount AdminConstraint on /admin routes."

  def call
    context.config.x.admin_sso_required ? pass("SSO enforced") : fail_with("Admin is not behind SSO")
  end
end
Forseti::Scanner.register(InternalAuthCheck)
```

Planned for later phases:

```ruby
Forseti.configure do |config|
  config.security.enable!
  config.privacy.filter_parameters!
  config.compliance.enable :gdpr
  config.audit.enable!
end
```

## Roadmap

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 0 | Gem skeleton, configuration system, CI | ✅ done |
| 1 | Scanner, Reporting, `forseti:doctor` (13 checks) | ✅ done |
| 2 | Security module (headers, CSP, cookies, session) | 🔜 next |
| 3 | PII registry, Privacy (filtering, redaction) | planned |
| 4 | Audit trail | planned |
| 5 | Compliance engine (GDPR, then CCPA/LGPD/DPDP) | planned |
| 6 | Consent & Retention | planned |

## Requirements

Ruby ≥ 3.2, Rails ≥ 7.1. Active Record is optional — only persistence-backed
modules (Audit, Consent, Retention) require it.

## Contributing

Forseti is design-first: see [CONTRIBUTING.md](CONTRIBUTING.md) for the
feature workflow and [docs/design](docs/design) for architecture decision
records.

## License

[MIT](LICENSE.txt).
