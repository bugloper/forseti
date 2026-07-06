# ADR 001: Scanner, Reporting, and `forseti:doctor`

- **Status:** Accepted
- **Date:** 2026-07-06
- **Depends on:** ADR 000 (D3, D5, D7, D10)

## 1. Problem

Rails applications have no feedback loop on their security configuration. A
team can disable `force_ssl`, ship an empty `filter_parameters`, or strip a
default security header and nothing tells them. Security posture degrades
silently — the operator only finds out during an incident or an external audit.

## 2. How Rails addresses it today

Rails generates secure-leaning defaults (`load_defaults`, default headers,
same-site cookies) and documents best practice in the Securing Rails
Applications guide. That's *provisioning*, not *verification*: nothing checks
that the defaults survived contact with a real codebase.

## 3. Limitations

- Defaults are point-in-time; config drifts over years of commits.
- `load_defaults` pins regress silently when apps upgrade Rails but not the pin.
- The guide is prose; compliance with it is unmeasurable.
- Brakeman analyzes source ASTs — it cannot see the *booted application's*
  effective configuration (initializer interplay, ENV-dependent settings,
  engine-injected middleware).

## 4. Why Forseti

This is the adoption wedge from ADR 000: zero-config, read-only, instant
value. It also feeds every later phase — Phase 2 enforcement is validated by
these checks, and Phase 5 compliance requirements reuse the same check
machinery.

## 5. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Static parsing of `config/environments/*.rb`** — no app boot needed, sees prod config from dev | Rejected: brittle against dynamic config (ENV branches, computed values). Runtime truth wins; CI can boot `RAILS_ENV=production`. |
| **Live HTTP probing** (issue requests, inspect real response headers) | Deferred: the most truthful signal, but requires a running server. Boot-time inspection covers Phase 1; a `--probe URL` mode can come later. |
| **Reuse Brakeman's engine** | Rejected: different domain (AST vs. runtime config). We stay complementary peers (ADR 000 §1). |
| **Checks as data (YAML rules)** vs. classes | Classes: checks need arbitrary Ruby introspection; a data DSL would grow into a worse language. Class metadata stays declarative. |

## 6. Public API

```bash
bin/rails forseti:doctor    # human report; exit 1 if failures ≥ scanner.fail_on
bin/rails forseti:score     # just the number and grade
bin/rails forseti:report    # machine-readable JSON on stdout
bin/rails forseti:checks    # list registered checks
```

(Rake-task form, not `rails forseti doctor` — colon-namespaced tasks are the
Rails-native extension point; a bare subcommand would require patching the
`rails` command.)

```ruby
Forseti.configure do |config|
  config.scanner.skip_checks = ["security.csp_nonce"]
  config.scanner.fail_on = :critical   # default :high; :none disables exit code
end

# Custom checks:
class InternalAuthCheck < Forseti::Scanner::Check
  id          "custom.internal_auth"
  severity    :high
  title       "Internal admin requires SSO"
  remediation "Mount AdminConstraint on /admin routes."

  def call
    context.config.x.admin_sso_required ? pass("SSO constraint present") : fail_with("Admin is not behind SSO")
  end
end
Forseti::Scanner.register(InternalAuthCheck)
```

## 7. Internal architecture

```text
Forseti::Scanner
├── Check      # base class: declarative metadata + pass/fail_with/skip helpers
├── Checks::*  # built-ins, one class per check, ids like "security.csp"
├── Context    # wraps the booted app (config, env, root); checks never touch globals
├── Registry   # id-keyed, register/unregister, deterministic order
├── Runner     # applicability, skip_checks, error isolation per check
├── Result     # :passed/:failed/:skipped/:error + message/details
├── Severity   # info < low < medium < high < critical
└── Config     # registered as Forseti.config.scanner

Forseti::Reporting
├── Report         # results + metadata; #to_h is the JSON schema (schema_version 1)
├── Score          # D10 formula
└── Formatters::{TTY, JSON}
```

Key behaviors:

- **Environment honesty.** Checks like `force_ssl` are only meaningful in
  production-like envs (`production`/`staging`). Elsewhere they report as
  *skipped with a reason*, never as passed — and doctor tells the user to run
  under `RAILS_ENV=production` in CI for full coverage.
- **Error isolation.** A crashing check becomes an `:error` result; it can
  never take down doctor or hide other findings.
- **Scoring (D10):** weights `critical:10 high:6 medium:3 low:1 info:0`;
  `score = 100 × (1 − Σfailed / Σapplicable)`; skipped and errored checks are
  excluded from the denominator. Grade bands A≥90 B≥80 C≥70 D≥60 else F, plus
  per-category subscores (`security.*`, `privacy.*`).
- **Behavioral checks over shape checks** where possible — e.g.
  `privacy.filter_parameters` runs probe keys through
  `ActiveSupport::ParameterFilter` rather than eyeballing the config array.

### Initial checks (13)

| id | severity | env |
|---|---|---|
| security.load_defaults | medium | any |
| security.force_ssl | critical | prod |
| security.hsts | high | prod (needs force_ssl) |
| security.host_authorization | medium | prod |
| security.cookies (same-site, httponly, secure-in-prod) | high | any |
| security.csp | high | any |
| security.csp_nonce | low | any (needs CSP) |
| security.default_headers | medium | any |
| security.csrf | high | any |
| security.open_redirects | medium | any |
| security.master_key (gitignored) | critical | any (needs file + git) |
| privacy.filter_parameters | high | any |
| privacy.log_level | medium | prod |

## 8. Performance

Doctor is a rake task; cost is dominated by app boot. Checks are O(1) config
reads. Nothing installs into the request path — zero production runtime cost.

## 9. Security implications

- Reports reveal posture (what's *missing*) — treat CI artifacts accordingly;
  documented in README.
- Reports must never contain secret *values*, only presence/absence. Review
  rule for all checks.
- Checks are read-only by contract; a check that mutates app state is a bug.

## 10. Testing strategy

- Per-check unit specs against a fake `Context` (hand-built config structs) —
  pass, fail, and skip paths for each.
- Unit specs for Registry (dup ids), Runner (error isolation, skip config),
  Severity, Score (formula edge cases: all skipped, zero applicable), Report,
  both formatters (JSON shape, TTY rendering with/without color).
- Integration: `Forseti::Scanner.run` against the dummy app (known posture:
  CSP and filter_parameters fail there).
- Rake smoke test via `Rails.application.load_tasks`.

## 11. Documentation

README doctor section with sample output; YARD on all public API; each check's
`title`/`description`/`remediation` metadata *is* its user documentation,
rendered in reports.

## 12. Implementation

Follows this ADR in the same change set.
