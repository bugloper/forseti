# ADR 003: PII Registry & Privacy Module (parameter filtering, log redaction)

- **Status:** Accepted
- **Date:** 2026-07-06
- **Depends on:** ADR 000 (D3, D9), ADR 001 (checks), ADR 002 (module pattern)

## 1. Problem

Rails apps leak PII through two chronic channels: request parameters that were
never added to `filter_parameters` (a hand-maintained list that lags the
schema — the dogfood app was missing `cvv` *as a payments processor*), and log
lines that embed PII in free text (`"sending receipt to jane@example.com"`),
which no parameter filter can catch. Meanwhile every tool that needs to know
"what counts as sensitive" — filtering, redaction, scanning, later compliance —
maintains its own hardcoded list.

## 2. How Rails addresses it today

`config.filter_parameters` (partial-match key filtering for params, and via
Active Record, `#inspect` output) with a generator-provided starter list.
Nothing for values already interpolated into log messages; no notion of PII
categories or sensitivity; the starter list never evolves with the app.

## 3. Limitations

- Key-based filtering only covers *structured* access; interpolated strings
  pass straight through to logs.
- The filter list is write-once: nothing audits it against what the app
  actually handles (Phase 1's check probes a fixed list — better, still static).
- "Sensitive" has no shared definition to build compliance on.

## 4. Why Forseti

D9 calls for one registry that defines PII once — detection patterns,
validators, sensitivity, recommended filter keys — and every consumer
(parameter filtering, log redaction, scanner probes, future compliance
classification) reads from it. Teach Forseti about `employee_badge` once and
every layer knows.

## 5. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Per-feature lists** (filter list, redactor list, scanner list) | Rejected — that's the status quo failure mode; lists drift apart. |
| **ML/NER-based PII detection** | Rejected for core: heavy, non-deterministic, un-auditable. The registry is deliberately regex+validator, reviewable line by line. |
| **Redact at the log *call site*** (wrap `Rails.logger.info`) | Rejected: requires monkey patching every logger method. A formatter decorator is the sanctioned extension point and catches all sinks. |
| **Redact inside `Logger#add`** via subclassing | Rejected: apps swap logger classes (semantic_logger, lograge); the formatter survives most of these, and BroadcastLogger propagates `formatter=`. |

## 6. Public API

```ruby
Forseti.configure do |config|
  config.privacy.enable!                 # filter_parameters :enforce + log redaction :report
  config.privacy.filter_parameters!      # just the parameter-filtering piece (vision API)
  config.privacy.log_redaction_mode = :enforce   # after :report looks right
  config.privacy.redact_types = %i[email credit_card ssn iban]
end

# Teach every layer about domain-specific PII at once:
Forseti::PII.register(:employee_badge,
                      sensitivity: :medium,
                      key_patterns: [/badge (number|id)/],   # matched against normalized names
                      filter_keys: %i[badge_number])

Forseti::PII.detect_key("user_email")      # => [email type]
Forseti::PII.detect_value("a@b.com")       # => [email type]
Forseti::PII.filter_keys                   # => union of every type's filter keys
```

## 7. Internal architecture

```text
Forseti::PII
├── Type       # key patterns, value pattern + validator, sensitivity, filter keys, probes
├── Registry   # register/lookup/detect; app-extensible like Scanner's
└── Builtins   # the 10 built-in types

Forseti::Privacy
├── Config       # filter_parameters_mode, log_redaction_mode, redact_types
└── LogRedactor  # formatter decorator
```

**Key detection** normalizes names (`"User_SSN"` → `"user ssn"`) so patterns
can use word boundaries (`\bssn\b` — a bare `\b` fails on snake_case since `_`
is a word character).

**Value detection is validator-backed** to kill false positives: credit cards
must pass Luhn (a random 16-digit id stays untouched), IBANs must pass mod-97,
IPv4 octets must be ≤ 255. Types whose values are arbitrary (passwords,
tokens) are key-detectable only.

**Built-ins (10):** email, phone (E.164-ish, `+`-prefixed values only),
credit_card, ssn (dashed form only — 9 bare digits is FP soup), iban,
ip_address, date_of_birth, password, api_credentials, national_id.
Sensitivities: critical (credentials, card, ssn, iban, national_id), high
(email, phone, dob), medium (ip).

**Parameter filtering** (`filter_parameters_mode :enforce`): engine
initializer after `:load_config_initializers` unions `Forseti::PII.filter_keys`
into `app.config.filter_parameters`. Safe ordering: that config is consumed
after initialization (request env config, AR `filter_attributes`), unlike the
middleware-built configs ADR 002 avoided. Union semantics — the app's own
entries are never removed.

**Log redaction** decorates `Rails.logger.formatter` in `after_initialize`:
- `:report` — detect PII in formatted lines and instrument
  `pii_detected.forseti` (payload carries type keys and **never the matched
  values**); lines untouched. `enable!` starts here, mirroring CSP report-only.
- `:enforce` — replace matches with `[REDACTED:email]` etc.
- Redaction only applies value-pattern types listed in `redact_types`
  (default: email, credit_card, ssn — phone/ip redaction would mangle normal
  request logs, so they're opt-in).
- Fail-open: any error returns the original line — a redactor bug must never
  eat logs. A thread-local guard prevents recursion when a notification
  subscriber itself logs.

**Scanner integration:** `privacy.filter_parameters` probes now come from the
registry (`Type#probes`). Probe set stays compatible with Rails' generated
filter list — the check shouldn't fail every default Rails app; stricter
coverage (card_number, phone) arrives via *enforcement*, not detection, and
later via compliance policies with an explicit bar.

## 8. Performance

Parameter filtering: zero runtime cost beyond Rails' own (one boot-time array
union). Redaction: N regex passes per log line (N = redact_types size, default
3), plus validators only on candidate matches. Opt-in and mode-gated; `:off`
costs nothing (formatter never wrapped).

## 9. Security implications

- Notification payloads and redaction markers must never include matched
  values (review rule, tested).
- Fail-open redaction is deliberate: losing logs is an availability incident;
  a missed redaction is what `:report` mode exists to find first.
- Regex DoS: all built-in patterns are linear (no nested quantifiers);
  registry docs warn custom patterns to stay so.

## 10. Testing strategy

Registry/Type units (normalization, Luhn/mod-97/octet validators, custom
registration, reset). LogRedactor units (enforce replaces each default type,
Luhn-invalid untouched, report instruments without mutating, fail-open on
raising formatter, recursion guard). Config unit (modes, enable!,
filter_parameters!). Scanner check spec extended for registry-driven probes.
E2E boot script verifying filter_parameters union + live log redaction.
Appraisal matrix.

## 11. Documentation

README privacy section; generator template gains the privacy block; YARD
throughout; `Forseti::PII.register` is the headline extension point.

## 12. Implementation

Follows in this change set.
