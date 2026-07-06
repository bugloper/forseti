# ADR 002: Security Module (headers, CSP baseline) & `forseti:install`

- **Status:** Accepted
- **Date:** 2026-07-06
- **Depends on:** ADR 000 (D3, D4, D5), ADR 001 (checks verify what this module enforces)

## 1. Problem

Doctor (Phase 1) tells teams what's missing; they still have to hand-write the
fixes. The most common gaps — missing security headers and no CSP — have
near-universal correct answers, yet every team re-derives them. And apps on the
archived `secure_headers` gem (like real-world app D2d) sit in limbo: headers
managed outside Rails, no migration path, and scanners that misread them.

## 2. How Rails addresses it today

Rails sets good default headers (`action_dispatch.default_headers`) and offers
a CSP DSL — but the CSP is opt-in and unset in most apps, default headers are
silently removable, and there is no "give me a safe baseline" switch.

## 3. Limitations

- No mechanism fills *missing* protections without overriding deliberate ones.
- Rails' CSP requires authoring a policy; most teams never start.
- Config-time settings can't adapt to what the response actually contains.

## 4. Why Forseti

`enable!` should convert doctor findings into applied protections with one
line — under D3's contract: report-first, enforce by explicit opt-in, never
override an app's explicit configuration.

## 5. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Mutate Rails config from an engine initializer** (set `default_headers`, CSP config) | Rejected: framework railties copy config into `ActionDispatch` constants during boot; whether a later mutation propagates depends on initializer ordering and shared-reference luck. Fragile across Rails versions. |
| **Response middleware that fills missing headers** | **Chosen.** Sees the final response, so "fill only what's absent" is exact; no boot-ordering hazards; trivially testable; uninstallable by config. |
| **Generate initializer code instead of runtime behavior** | Complementary, not sufficient — generated code drifts; the generator ships too, but the middleware is the contract. |
| **Adopt/wrap the `secure_headers` gem** | Rejected: archived upstream; Rails now owns these APIs. Forseti instead *detects* it (scanner) and offers a migration path. |

## 6. Public API

```ruby
Forseti.configure do |config|
  config.security.enable!            # headers_mode :enforce, csp_mode :report

  # Individual dials:
  config.security.headers_mode    = :enforce   # :off | :enforce
  config.security.csp_mode        = :enforce   # :off | :report | :enforce
  config.security.frame_options   = "DENY"     # default "SAMEORIGIN"
  config.security.referrer_policy = "no-referrer"
  config.security.csp_policy      = "default-src 'self'; ..."  # override baseline
  config.security.csp_report_uri  = "https://csp.example.com/reports"
end
```

```bash
bin/rails generate forseti:install   # writes config/initializers/forseti.rb
```

Semantics:

- **Fill, never override.** The middleware sets a header only when the
  response doesn't already have one (from Rails defaults, controllers, or
  other middleware). An app's explicit choice always wins.
- **`:report` CSP** sends `Content-Security-Policy-Report-Only` — observable
  in devtools/reports, breaks nothing. `enable!` starts there; moving to
  `:enforce` is a deliberate second step.
- The CSP baseline only applies to HTML responses that have no CSP header.

## 7. Internal architecture

```text
Forseti::Security
├── Config      # registered as Forseti.config.security
└── Middleware  # appended to the app stack when the module is enabled
```

- Engine initializer `forseti.security.middleware` runs
  `after: :load_config_initializers` (so the app's `Forseti.configure` has
  run) and appends the middleware only when `security.enabled?` — an app that
  never calls `enable!` gets an untouched middleware stack (D3).
- Header names are lowercased under Rack 3 (Rails 7.1 may run Rack 2);
  presence checks are case-insensitive.
- Baseline CSP (versioned with defaults, D4):
  `default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:;
  font-src 'self' data:; object-src 'none'; frame-ancestors 'self';
  base-uri 'self'; form-action 'self'` — no nonce support in the baseline;
  apps needing nonces should graduate to Rails' CSP DSL (the scanner nudges
  via security.csp_nonce).
- **Scanner awareness (closing the loop):** `security.default_headers` and
  `security.csp` now recognize (a) Forseti's own enforcement — the D5 payoff:
  config is introspectable — and (b) the `secure_headers` gem: headers checks
  skip with a reason; the CSP check introspects it defensively and *fails* when
  CSP is `SecureHeaders::OPT_OUT` (a real misconfiguration found in the wild:
  a policy defined and then overridden by opt-out three lines later).

### Deliberate scope cuts (deferred, not forgotten)

- Runtime cookie/session hardening (same-site, httponly): needs config
  mutation before the cookie middleware is built — the ordering problem above.
  Phase 1 checks + generator guidance cover it for now; revisit with a
  dedicated design.
- `Permissions-Policy` baseline: any deny-by-default set breaks some app
  (`payment=()` would break a PSP). Needs per-feature configuration design.
- HSTS filling: already handled correctly by `force_ssl`; doctor flags it.

## 8. Performance

One `O(headers)` pass per response, a handful of string comparisons; no
allocation when everything is already set. Not in the stack at all unless
enabled.

## 9. Security implications

- A report-only CSP can create a false sense of protection — doctor keeps
  reporting `:report` mode as a caveat, never as full credit.
- Filling `frame_options "SAMEORIGIN"` on responses that intentionally allow
  framing would break embedding — hence fill-never-override plus per-setting
  dials.
- The middleware must never *remove* or *rewrite* headers. Fill-only contract.

## 10. Testing strategy

Middleware unit specs against a lambda app (fill vs. don't-override, HTML
gating, report vs. enforce header names, Rack 2/3 casing, disabled = untouched
stack). Config spec (modes, enable! defaults). Scanner-awareness specs
(Forseti-enforced → pass; secure_headers present → skip; OPT_OUT → fail).
Generator spec writes and re-runs idempotently. Appraisal matrix as always.

## 11. Documentation

README "one-line hardening" section; generator template is self-documenting
(commented dials); upgrade note for secure_headers-gem users.

## 12. Implementation

Follows in this change set.
