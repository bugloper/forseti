# ADR 000: Foundations

- **Status:** Proposed
- **Date:** 2026-07-06
- **Scope:** Gem-wide decisions that every module inherits. Individual features get
  their own design docs (001+) following the 12-step workflow in CONTRIBUTING.

---

## 1. Strategic position

### The problem

Rails ships strong security primitives — CSP DSL, HSTS via `force_ssl`,
`filter_parameters`, Active Record encryption, host authorization, signed/encrypted
cookies, versioned `load_defaults`. But they are *scattered, opt-in, and unverified*:

1. **No feedback loop.** Nothing tells a team "your session cookie lacks
   `SameSite`, your CSP is missing, your `filter_parameters` doesn't cover the
   `ssn` column you added last sprint." Brakeman covers static code smells;
   nothing audits the *running configuration*.
2. **No compliance layer.** GDPR/CCPA/LGPD/DPDP obligations (consent, retention,
   erasure, portability, audit trails) have no Rails-native answer — teams
   hand-roll them or stitch together five unmaintained gems.
3. **No shared vocabulary.** "Is this app secure?" has no measurable answer.

### What Forseti is — and is not

- Forseti **unifies and verifies**; it does not reimplement Rails security
  features. Wherever a Rails API exists, Forseti configures it, checks it, and
  reports on it.
- Forseti **complements Brakeman**, it does not compete with it. Brakeman does
  static AST analysis of code; Forseti audits runtime configuration and posture,
  and provides the compliance/privacy layer Brakeman never will. The scanner may
  *consume* Brakeman/bundler-audit output later; it will not rebuild them.
- Forseti provides **compliance primitives and evidence, not legal guarantees**.
  All docs and output say "helps you meet" — never "makes you compliant." This
  is a liability posture, enforced in review.

### Adoption wedge

Devise won by doing one thing indispensably well before it was a framework.
Forseti's wedge is **`bin/rails forseti:doctor`** — add the gem, run one
command, get a scored, actionable security posture report with zero
configuration and zero behavior change. Read-only, instant value, safe to try
on any production app, and naturally viral ("we're at 61/100, let's fix the
red ones"). Everything else earns trust from there.

---

## 2. Foundational decisions

### D1 — Single gem, modular inside

One gem, `forseti`, with modules lazy-loaded and independently enable-able. No
meta-gem constellation (`forseti-core`, `forseti-gdpr`, …) at this stage:
multi-gem splits multiply CI, versioning, and contributor overhead before there
are contributors. The namespace discipline (each module self-contained, coupled
only through `Forseti::Core`) keeps later extraction cheap if a module grows a
life of its own.

### D2 — Rails::Engine, features tiered by footprint

Forseti ships as an isolated `Rails::Engine` (`isolate_namespace Forseti`),
because Consent, Audit, and Retention eventually need models, migrations, and
routes. But the engine is inert by default. Features come in three tiers:

| Tier | Footprint | Examples |
|------|-----------|----------|
| **Observe** | Read-only, no app changes | Scanner, Reporting, doctor |
| **Configure** | Middleware / Rails config, no DB | Security headers, cookie hardening, param filtering |
| **Persist** | Models + migrations, via generators only | Audit log, Consent, Retention |

Nothing in the Persist tier activates without an explicit generator run. Active
Record is a *soft* dependency: hard deps are `railties` + `activesupport` only;
Persist-tier modules raise a clear error if AR is absent.

### D3 — Observe by default, enforce by opt-in

Installing the gem changes **nothing** about app behavior. Every enforcing
feature has a per-feature mode:

- `:off` — inert
- `:report` — detect and log/notify violations, never block (like CSP report-only)
- `:enforce` — actively apply/block

`config.security.enable!` turns a module's features to their recommended
enforcing defaults; individual features can be dialed back. This resolves the
"secure by default" vs "backwards compatible" tension in the brief: *Forseti's
recommendations* are secure by default; *its installation* is safe by default.

### D4 — Versioned defaults, Rails-style

`config.forseti.defaults = "1.0"` pins the default set, exactly like Rails'
`load_defaults`. New Forseti versions may add stricter recommendations behind a
new defaults version; upgrading the gem never silently changes behavior.

### D5 — Explicit, validated configuration objects

Each module gets a real config class (not `OrderedOptions`): typos raise,
values are validated at boot, and every option is introspectable — which is
what lets the Scanner audit Forseti's own configuration. The top-level API:

```ruby
Forseti.configure do |config|
  config.security.enable!                 # recommended enforcing defaults
  config.security.csp.mode = :report      # dial one feature back

  config.privacy.filter_parameters!

  config.compliance.enable :gdpr
  config.audit.enable!
end
```

### D6 — ActiveSupport::Notifications as the event backbone

Audit-worthy events are *instrumented*, not directly written:
`Forseti.instrument("audit.forseti", …)`. The Audit module's sinks (AR table,
logger, external SIEM adapter) are subscribers. Emitters and sinks stay
decoupled; apps can add subscribers without touching Forseti internals; nothing
is monkey-patched.

### D7 — Scanner as a check registry

A check is a small class with metadata (`id`, `title`, `severity`, `tags`,
`applies?`, `remediation`) that returns `Finding`s. Checks are registered, not
hardcoded, so apps and third-party gems can contribute their own. Output goes
through formatters: TTY (human), JSON (machine), SARIF later for GitHub code
scanning. Severity vocabulary: `critical / high / medium / low / info`.

### D8 — Compliance as a policy engine with two requirement kinds

A regulation (GDPR, CCPA, LGPD, DPDP) is a `Policy`: a versioned set of
`Requirement`s, each mapped to the legal control it addresses (e.g. GDPR
Art. 17). Requirements come in two kinds, and conflating them is the classic
compliance-tool mistake:

- **Checkable** — machine-verifiable from the app (retention policy declared,
  audit trail active, erasure endpoint wired, params filtered).
- **Attestable** — cannot be verified from code (DPAs signed, DPO appointed).
  Forseti tracks these as explicit human attestations with author + date, and
  reports them as such — never as automatically "passing."

Policies are data-driven definitions so regulations can be added or amended
without touching the engine.

### D9 — Shared PII registry

One `Forseti::PII` registry — detection patterns (column-name heuristics, value
regexes, format validators) with confidence levels — consumed by parameter
filtering, log redaction, the scanner, and compliance checks alike. One place
to teach Forseti what "sensitive" means in a given app.

### D10 — Scoring is transparent

`forseti:score` uses a published, documented formula (severity-weighted, N/A
checks excluded from the denominator, per-module subscores). A score no one can
explain is a score no one trusts. The formula is versioned alongside defaults.

---

## 3. Target namespace (v1 horizon)

```text
Forseti
├── Core          # configuration, defaults versioning, registry plumbing
├── Security      # headers, CSP, HSTS, cookies, session, redirects, uploads
├── Privacy       # param filtering, log redaction, masking
├── PII           # shared detection/classification registry (D9)
├── Compliance    # policy engine + GDPR/CCPA/LGPD/DPDP definitions
├── Consent       # consent records, cookie consent        [Persist tier]
├── Retention     # retention policies, scheduled deletion [Persist tier]
├── Audit         # event trail, sinks                     [Persist tier]
├── Scanner       # check registry + runner
├── Reporting     # scores, findings, formatters (TTY/JSON)
├── Generators    # forseti:install, forseti:audit, forseti:consent, …
└── CLI           # rake tasks: forseti:doctor, :score, :report, :compliance
```

`Encryption` from the original sketch folds into Security/Privacy helpers over
Active Record encryption rather than being its own module — Rails 7+ already
owns that problem; Forseti verifies and eases it. `Policies` is renamed
`Compliance` internally to avoid collision with the Pundit-style meaning of
"policy" in the Rails ecosystem.

---

## 4. Tooling & quality bar

- **Ruby 3.2+, Rails 7.1+** (7.0 is EOL for bug fixes; supporting it buys
  little). CI matrix: Ruby 3.2/3.3/3.4 × Rails 7.1/7.2/8.0 × sqlite/postgres/mysql
  via Appraisal + GitHub Actions.
- **Zeitwerk** for gem autoloading; modules lazy-load so unused features cost
  nothing at boot.
- **RSpec** + a dummy Rails app for engine/integration specs (the dominant
  convention for community-contributed Rails gems).
- **RuboCop** (rubocop-rails, rubocop-rspec, rubocop-performance) from commit one.
- **No monkey patching.** Integration via Railtie initializers, middleware,
  `ActiveSupport.on_load` hooks, and opt-in concerns. A PR that reopens a Rails
  class needs an ADR justifying it.
- Every public API documented with YARD; every feature lands with a design doc.

---

## 5. Roadmap

| Phase | Deliverable | Why this order |
|-------|-------------|----------------|
| **0** | Gem skeleton: engine, config system (D3–D5), CI matrix, dummy app | Everything sits on the config system |
| **1** | Scanner + Reporting + `forseti:doctor` / `:score` (~15 config-posture checks) | The adoption wedge; read-only, zero risk |
| **2** | Security module (headers, CSP, HSTS, cookies, session) + `forseti:install` | First enforcement, validated by Phase 1's checks |
| **3** | PII registry + Privacy (param filtering, log redaction) | Feeds scanner and everything downstream |
| **4** | Audit module + generator | Prerequisite evidence layer for compliance |
| **5** | Compliance engine + GDPR policy (then CCPA, LGPD, DPDP) | Needs Audit + PII to have anything to check |
| **6** | Consent + Retention | Highest-footprint features last, on a proven base |

Each phase ships as a usable release; the gem is never in a state where half a
feature is exposed.

---

## 6. Open questions (to resolve in feature ADRs)

1. Standalone `forseti` binary for CI that boots the app in a sandboxed env,
   vs. rake-tasks-only? (Leaning rake-only until Phase 1 proves the need.)
2. Should doctor optionally shell out to Brakeman/bundler-audit and merge
   findings into one report? (Attractive, but keep them optional peers.)
3. Audit log storage: same-database table vs. pluggable sink-first design with
   AR as the default sink. (Leaning sink-first per D6.)
4. Minimum viable consent model — server-side records only, with cookie-banner
   frontend as a separate concern/example, not shipped JS?
