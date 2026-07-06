# ADR 004: Audit Module (event trail, sinks, `forseti:audit`)

- **Status:** Accepted
- **Date:** 2026-07-06
- **Depends on:** ADR 000 (D2 Persist tier, D3, D6), ADR 003 (PII filtering of metadata)

## 1. Problem

Security- and compliance-relevant *events* — logins, role and permission
changes, sensitive record access, data exports, deletions, admin actions —
need a durable, append-only, queryable trail. Log files rotate away, aren't
structured for "show me everything this admin did in March", and satisfy no
auditor. Phase 5's compliance engine needs this trail as its evidence layer.

## 2. How Rails addresses it today

`ActiveSupport::Notifications` (ephemeral pub/sub, no durability),
`ActiveRecord` callbacks, and logs. Nothing ships an audit trail.

## 3. Limitations

Notifications vanish unless something durable subscribes; hand-rolled audit
tables grow inconsistent shapes per team; log-based auditing can't answer
entity-scoped questions or survive rotation.

## 4. Why Forseti

One event vocabulary + one durable trail that compliance checks can later
point at as evidence ("erasure requests are audited"). And PII discipline for
free: audit metadata passes through the ADR 003 registry filter, so the audit
trail can't itself become a PII dump.

## 5. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Reuse audited/paper_trail** | Rejected: they version *model attribute changes*. Security events (logins, exports, permission grants) mostly aren't model writes. Complementary, not overlapping. |
| **Pure AS::Notifications subscriber model** (ADR 000's D6 lean: sinks are subscribers) | *Refined*: global subscription lifecycle (enable/disable/test cleanup) is state with no gain. `Audit.record` dispatches to sinks directly **inside** an `audit.forseti` instrumentation block — apps still get the event stream for their own integrations; delivery doesn't depend on subscription order. |
| **Hard AR dependency, table-only** | Rejected per D2. Sink-first: `:active_record` is the default sink, `:logger` (JSON lines) works with zero database, custom sinks (SIEM, Kafka, WORM stores) are any object with `#write(event)`. |
| **Async delivery via ActiveJob** | Deferred: needs event serialization + a queue dependency. Synchronous writes are correct-by-default for audit; an `:async` wrapper sink can come later. |

## 6. Public API

```ruby
Forseti.configure do |config|
  config.audit.enable!
  config.audit.sinks = [:active_record]          # default; also :logger, or any #write(event)
  config.audit.on_sink_error = :report           # :report (Rails.error) | :raise
  config.audit.actor_method = :current_user      # what the controller concern calls
end

# Anywhere:
Forseti::Audit.record(:role_changed,
                      actor: admin, subject: user,
                      metadata: { from: "member", to: "admin" })

# Controllers — sets actor/ip/user_agent/request_id once per request:
class ApplicationController < ActionController::Base
  include Forseti::Audit::Controller
end
# ...after which call sites shrink to:
Forseti::Audit.record(:data_export, subject: report)
```

```bash
bin/rails generate forseti:audit   # migration for forseti_audit_events
```

Semantics:

- `record` is a **no-op unless the module is enabled** (D3) and returns the
  event (or nil). Explicit arguments always beat ambient context;
  `actor: nil` explicitly records an actorless system event.
- Ambient context lives in `Forseti::Audit::Current`
  (ActiveSupport::CurrentAttributes — reset per request by Rails' executor).
- Metadata is filtered through Rails' `filter_parameters` ∪
  `Forseti::PII.filter_keys` before storage.
- Sink failures: isolated per sink; `:report` (default) sends to
  `Rails.error` and keeps the request alive — losing one audit write is
  reported, taking down production isn't. `:raise` for apps whose compliance
  posture requires fail-closed writes.

## 7. Internal architecture

```text
Forseti::Audit
├── Config      # sinks, actor_method, on_sink_error
├── Current     # per-request ambient context (CurrentAttributes)
├── Controller  # opt-in concern that fills Current
├── Event       # immutable value object; #to_h is the sink contract
└── Sinks
    ├── ActiveRecord  # -> Forseti::AuditEvent (app/models, Persist tier)
    └── Logger        # single-line JSON to Rails.logger

app/models/forseti/audit_event.rb   # append-only AR model
```

- **Append-only:** `AuditEvent#readonly?` returns true once persisted —
  updates and destroys raise `ActiveRecord::ReadOnlyRecord`. (`delete_all`
  bypasses AR; deliberate pruning arrives with Retention in Phase 6.)
- **Fail-fast boot (D2):** with audit enabled, `after_initialize` verifies
  sinks; the `:active_record` sink without Active Record loaded raises a
  clear error pointing at `sinks = [:logger]`. A *missing table* is not a
  boot error (apps boot before migrating on deploy) — the new
  `audit.storage` scanner check catches it instead.
- **Model loading:** the engine's `app/models` is on the host app's autoload
  paths; the model is only resolved on first reference, preserving the
  AR-less boot guarantee.

### Test harness (the Persist-tier question from ADR 000)

Two RSpec invocations, one process each: the main suite keeps the AR-less
dummy (`rake spec`, `.rspec` excludes `spec/ar/`), and `rake spec:ar` runs
`spec/ar/` via `.rspec-ar`, whose helper loads Active Record standalone
(in-memory SQLite, schema defined inline) *on top of* the AR-less dummy —
proving the engine model and AR sink work without the AR railtie ever
booting. The Zeitwerk spec now eager-loads the gem's own loader
(`Forseti.eager_load!`) instead of `Zeitwerk::Loader.eager_load_all`, which
would force the engine model to load AR-less.

## 8. Performance

One event = one filter pass over metadata + one insert per sink, synchronous
by design. Audit events are low-frequency (security actions, not page views).
Indexes on action, actor, subject, occurred_at, request_id for the queries
auditors actually run.

## 9. Security implications

- Metadata PII-filtered before storage; the `audit.forseti` payload carries
  the same filtered event.
- Append-only at the model layer; DB-level immutability (revoked UPDATE/
  DELETE grants, WORM storage) is documented guidance, not enforced.
- `:report` default trades absolute audit completeness for availability —
  documented, and reversible via `:raise`.
- IP/user-agent are personal data under GDPR — the trail itself will fall
  under Phase 6 retention policies.

## 10. Testing strategy

AR-less suite: record gating, context merge/override, metadata filtering,
logger sink JSON shape, sink error isolation (:report vs :raise), unknown
sink errors, config validation. `spec/ar`: model append-only semantics, AR
sink round-trip, `audit.storage` check, migration generator output. Matrix
gets per-appraisal sqlite3 pins (Rails 7.1 needs sqlite3 1.x).

## 11. Documentation

README audit section; generator template gains the audit block; event
vocabulary conventions (past-tense verbs: `:role_changed`, `:data_exported`)
documented in YARD on `Audit.record`.

## 12. Implementation

Follows in this change set.
