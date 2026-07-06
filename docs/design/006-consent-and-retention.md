# ADR 006: Consent & Retention

- **Status:** Accepted
- **Date:** 2026-07-06
- **Depends on:** ADR 000 (D2 Persist tier), ADR 004 (audit events, append-only model, AR harness), ADR 005 (requirements flip to checkable)

## 1. Problem

Two obligations every privacy regulation shares, and Rails apps chronically
fail: **consent** must be provable (who, what purpose, which policy text,
when, withdrawable — GDPR Art. 7, DPDP §6), yet apps model it as a boolean
column that answers none of that; and **storage limitation** (GDPR
Art. 5(1)(e), DPDP §8(7)) requires deleting data when its purpose is served,
yet production databases delete nothing, ever.

## 2. How Rails addresses it today

It doesn't. Active Record can model anything, so every team models consent
differently (usually wrong: no history, no version, no withdrawal proof) and
writes retention crons ad hoc (usually never).

## 3. Limitations

A boolean can't prove *which* policy text was consented to or when consent
was withdrawn. Hand-rolled deletion scripts have no dry-run, no audit trail
of what they deleted, and silently rot.

## 4. Why Forseti

These are the two primitives that turn ADR 005's attestable rights into
checkable ones — the flip the GDPR/DPDP policies have annotated since Phase 5.
And retention finally provides the *deliberate* pruning path the append-only
audit trail has pointed at since ADR 004.

## 5. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Mutable consent row** (granted_at/withdrawn_at per subject+purpose) | Rejected: loses history — the entire evidentiary value. Append-only records, same philosophy as audit; current state = latest record. |
| **Ship a cookie-consent banner (JS/views)** | Rejected for core: frontend consent UX is app-specific and framework-churny. Forseti is the *server-side system of record* the banner talks to. |
| **No-op consent writes when the module is disabled** (Audit.record's D3 pattern) | Rejected: silently dropping a consent grant destroys legal evidence. Consent API calls are already explicit opt-in; they work regardless of `enable!`, which instead gates boot verification and compliance signaling. |
| **Auto-schedule retention runs** | Rejected: Forseti doesn't own a scheduler. `forseti:retention:run` is the idempotent entry point; cron/solid_queue/whenever invoke it. |
| **Flip GDPR consent/storage requirements to purely checkable** | Rejected: apps legitimately manage consent in external systems (CMPs). New requirement option `or_attested:` — machine evidence satisfies it, a valid attestation is the fallback. Never silently; the report says which. |

## 6. Public API

```ruby
Forseti.configure do |config|
  config.consent.enable!
  config.consent.purposes = %i[marketing_emails analytics]   # optional strictness

  config.retention.policy :stale_audit_events,
                          model: "Forseti::AuditEvent",
                          keep_for: 2.years, timestamp: :occurred_at, strategy: :delete
  config.retention.policy :abandoned_carts,
                          model: "Cart", keep_for: 90.days,
                          scope: ->(carts) { carts.where(completed_at: nil) }
end
```

```ruby
Forseti::Consent.grant(user, :marketing_emails, policy_version: "2026-03")
Forseti::Consent.withdraw(user, :marketing_emails)
Forseti::Consent.granted?(user, :marketing_emails)                            # current state
Forseti::Consent.granted?(user, :marketing_emails, policy_version: "2026-04") # false → re-consent flow
Forseti::Consent.history(user, :marketing_emails)                             # the evidence
```

```bash
bin/rails generate forseti:consent      # migration for forseti_consent_records
bin/rails forseti:retention:preview     # dry run — counts only, deletes nothing
bin/rails forseti:retention:run         # prune + audit event per policy
```

## 7. Internal architecture

```text
Forseti::Consent                        Forseti::Retention
├── Config (purposes)                   ├── Config (policy DSL → policies)
└── facade: grant/withdraw/granted?/    ├── Policy (model, keep_for, timestamp,
    history/verify!                     │          scope, strategy :destroy|:delete)
app/models/forseti/consent_record.rb    └── facade: run / preview
```

**Consent** — append-only `forseti_consent_records` (subject polymorphic,
purpose, action granted/withdrawn, policy_version, metadata, ip_address from
`Audit::Current`, created_at). Current state = newest record per
subject+purpose; `granted?` with `policy_version:` returns false when the
latest grant predates the version — the re-consent trigger. Declared
`purposes` make typos raise. Every grant/withdrawal also emits a
`consent_granted`/`consent_withdrawn` audit event (no-op if audit disabled).
Persist-tier fail-fast: boot verification when enabled, clear error pointing
at the generator.

**Retention** — a policy names a model, a horizon (`keep_for` before
`timestamp`, default `:created_at`), an optional scope, and a strategy:
`:destroy` (default — callbacks and dependents run; right for user-ish data)
or `:delete` (`delete_all`; required for the readonly audit model, right for
high-volume rows). `preview` never deletes. `run` isolates failures per
policy (one bad policy can't block the others; errors → `Rails.error`) and
records a `retention_pruned` audit event with the count — deletion is itself
a compliance action.

**Compliance flip (ADR 005 §7 fulfilled):** `or_attested: true` lands on
requirements where machine evidence *or* an attestation satisfies:
GDPR `consent_management` now verifies `config.consent.enabled?`, a new GDPR
`storage_limitation` (Art. 5(1)(e)) verifies retention policies exist, and
DPDP `notice_and_consent` verifies consent. Reports still label the source
(verified vs attested). Erasure/portability stay attestable — request-driven
DSR orchestration is deliberately post-1.0 scope.

**Scanner:** new `consent.storage` check (mirror of `audit.storage`).

## 8. Performance

Consent reads are one indexed query per subject+purpose (apps should cache
hot paths). Retention runs are operator-invoked, off the request path;
`delete_all` for volume, `destroy` batched via `find_each`.

## 9. Security implications

- Consent records are PII-adjacent evidence — deliberately *excluded* from
  retention's reach by nothing but operator care; documented loudly (deleting
  consent history destroys proof; regulations require keeping it).
- `strategy: :delete` bypasses callbacks by design; the docs say when that's
  wrong. The audit model's readonly guard forces the choice consciously.
- Retention with a bad scope can mass-delete: `preview` exists exactly for
  that, and every run leaves an audit event with counts.

## 10. Testing strategy

AR-less suite: config DSLs (purpose validation, duplicate/invalid retention
policies), consent verify!/availability errors, evaluator `or_attested`
matrix, `consent.storage` check gating. `spec/ar`: grant/withdraw/history/
version semantics, append-only enforcement, audit event emission, retention
preview/run against seeded models (both strategies, scopes, per-policy error
isolation, audit-trail pruning through the readonly model). Generator specs.
Matrix as always.

## 11. Documentation

README consent + retention sections (with the "never retain-away your
consent records" warning); install template gains both blocks; scheduling
guidance (cron/solid_queue) in the task descriptions.

## 12. Implementation

Follows in this change set.
