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

## One-line hardening

```bash
bin/rails generate forseti:install   # writes config/initializers/forseti.rb
```

```ruby
Forseti.configure do |config|
  config.defaults = "1.0"
  config.security.enable!
end
```

`security.enable!` fills missing security headers (X-Content-Type-Options,
X-Frame-Options, Referrer-Policy, X-Permitted-Cross-Domain-Policies) on every
response and adds a baseline Content-Security-Policy — in **report-only mode**
— to HTML responses that have none. The contract is *fill, never override*: a
header your app already sets, at any layer, always wins. When report-only
looks clean in production, flip `config.security.csp_mode = :enforce`.

Apps using the archived `secure_headers` gem are recognized: header checks
step aside, and the scanner flags the classic `SecureHeaders::OPT_OUT`
misconfiguration where a defined CSP is silently dead.

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

## PII protection

```ruby
Forseti.configure do |config|
  config.privacy.enable!   # PII-driven parameter filtering + log redaction (report mode)
end

# Teach every layer — filtering, log redaction, scanner coverage — about
# domain-specific PII at once:
Forseti::PII.register(:employee_badge,
                      sensitivity: :medium,
                      key_patterns: [/badge (number|id)/],
                      filter_keys: %i[badge_number])
```

The PII registry defines what "sensitive" means, once: 10 built-in types
(email, phone, credit card, SSN, IBAN, IP, date of birth, password, API
credentials, national ID) with validator-backed value detection — credit
cards must pass Luhn, IBANs mod-97 — so a random 16-digit ID is never
mangled. `enable!` extends `config.filter_parameters` with the registry's
keys (never removing yours) and watches log lines for interpolated PII —
the leak no parameter filter can catch — reporting via the
`pii_detected.forseti` notification (type names only, never values). Flip
`config.privacy.log_redaction_mode = :enforce` to replace matches with
`[REDACTED:email]`. Redaction fails open: a redactor error can never eat a
log line.

## Audit trail

```bash
bin/rails generate forseti:audit && bin/rails db:migrate
```

```ruby
Forseti.configure { |config| config.audit.enable! }

class ApplicationController < ActionController::Base
  include Forseti::Audit::Controller   # fills actor/ip/request context per request
end

Forseti::Audit.record(:role_changed, actor: admin, subject: user,
                      metadata: { from: "member", to: "admin" })
```

Events land in an append-only `forseti_audit_events` table (updates and
destroys raise) — or in any sink you like: `:logger` emits single-line JSON
with zero database, and custom sinks are any object with `#write(event)`.
Metadata is filtered through the PII registry before storage, so the audit
trail can't become a PII dump. Sink failures are isolated and reported via
`Rails.error` by default (`config.audit.on_sink_error = :raise` to fail
closed), every event also fires the `audit.forseti` notification, and the
`audit.storage` doctor check catches a pending migration before your trail
silently drops events.

## Compliance

```ruby
Forseti.configure do |config|
  config.compliance.enable :gdpr    # also :ccpa, :lgpd, :dpdp
end
```

```bash
bin/rails generate forseti:compliance    # attestations.yml skeleton
bin/rails forseti:compliance             # per-policy report; exit 1 on unmet
```

Each policy is a set of requirements mapped to legal controls. Requirements
Forseti can machine-verify (transport security → GDPR Art. 32, PII-free logs
→ Art. 5(1)(c), an audit trail → Art. 33) are evaluated against the live app
via the scanner. Everything else — DPAs, notices, officers — is satisfied
**only** by an explicit human attestation in `config/forseti/attestations.yml`
(who, when, optional expiry), reviewed in git like code. Reports always
distinguish `[verified]` from `[attested by jane@corp.com on 2026-07-01]`,
and requirements whose evidence couldn't run report as *unverified*, never as
passing. Custom org policies plug into the same engine via
`Forseti::Compliance.define_policy`.

> **Forseti provides technical evidence and checklists, not legal advice.**
> A passing report does not constitute or guarantee regulatory compliance.
> That disclaimer is part of every report, by design.

## Roadmap

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 0 | Gem skeleton, configuration system, CI | ✅ done |
| 1 | Scanner, Reporting, `forseti:doctor` (13 checks) | ✅ done |
| 2 | Security module (headers, baseline CSP) + `forseti:install` | ✅ done |
| 3 | PII registry, Privacy (filtering, redaction) | ✅ done |
| 4 | Audit trail (sinks, append-only storage, `forseti:audit`) | ✅ done |
| 5 | Compliance engine (GDPR, CCPA, LGPD, DPDP + attestations) | ✅ done |
| 6 | Consent & Retention | 🔜 next |

## Requirements

Ruby ≥ 3.2, Rails ≥ 7.1. Active Record is optional — only persistence-backed
modules (Audit, Consent, Retention) require it.

## Contributing

Forseti is design-first: see [CONTRIBUTING.md](CONTRIBUTING.md) for the
feature workflow and [docs/design](docs/design) for architecture decision
records.

## License

[MIT](LICENSE.txt).
