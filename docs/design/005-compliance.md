# ADR 005: Compliance Engine (policies, attestations, GDPR/CCPA/LGPD/DPDP)

- **Status:** Accepted
- **Date:** 2026-07-06
- **Depends on:** ADR 000 (D8, D10), ADR 001 (checks as evidence), ADR 004 (audit trail as evidence)

## 1. Problem

"Where do we stand on GDPR?" has no Rails-native answer. Regulations decompose
into requirements; *some* are machine-verifiable from the app (encryption in
transit, parameter filtering, an audit trail), most are organizational (DPAs
signed, notices published, officers appointed). Teams track this in stale
spreadsheets disconnected from the code that implements it.

## 2. How Rails addresses it today

It doesn't — correctly, since this is above the framework's pay grade. The gem
ecosystem offers point solutions (consent banners, DSR request handlers) but
no requirement→evidence mapping.

## 3. Limitations

Point solutions can't say what's *missing*. Spreadsheets drift from reality
the day they're written. Nothing connects "config.force_ssl = true" to
"GDPR Art. 32" where an auditor can see it.

## 4. Why Forseti

Phases 1–4 built exactly the evidence a compliance evaluation needs: scanner
checks (technical controls), the PII registry (data classification), and the
audit trail (accountability). Phase 5 maps them to legal controls — and is
honest about everything it *cannot* verify.

## 5. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Report only machine-checkable items** | Rejected: a "compliance report" silently omitting 70% of a regulation is worse than none — it manufactures false confidence. |
| **Auto-pass attestable items when a flag is set in Ruby config** | Rejected (D8): attestation needs *who* and *when*, reviewably. |
| **Attestations in the database** | Rejected for v1: attestations are governance artifacts — a YAML file (`config/forseti/attestations.yml`) lives in git, gets code-reviewed, and needs no migration. |
| **Policies as YAML data** | Rejected: checkable requirements need Ruby (procs, check references). Policies are Ruby definitions with declarative metadata — same call as the check DSL (ADR 001 §5). |

## 6. Public API

```ruby
Forseti.configure do |config|
  config.compliance.enable :gdpr      # vision API — validates the key exists
  config.compliance.enable :ccpa
end
```

```bash
bin/rails generate forseti:compliance   # attestations.yml skeleton
bin/rails forseti:compliance            # per-policy report; exit 1 on unmet
FORMAT=json bin/rails forseti:compliance
```

```yaml
# config/forseti/attestations.yml — reviewed like code, in git history
gdpr:
  records_of_processing:
    attested_by: "jane@corp.com"
    attested_on: 2026-07-01
    note: "RoPA maintained in Confluence/LEG-12"
    expires_on: 2027-07-01   # optional; expired attestations count as unmet
```

Custom org policies use the same engine:

```ruby
Forseti::Compliance.define_policy(:acme_baseline, name: "ACME Security Baseline", version: "2026.1") do |p|
  p.requirement :sso_everywhere, title: "All admin surfaces behind SSO",
                article: "SEC-4", checks: %w[custom.internal_auth]
end
```

## 7. Internal architecture

```text
Forseti::Compliance
├── Config          # enabled policies, attestations_path
├── Policy          # key, name, version, requirements (DSL-built, frozen)
├── Requirement     # article, title; kind derived: checkable | attestable
├── Attestations    # YAML loader; validity = who + when + not expired
├── Evaluator       # one policy + context + attestations → PolicyResult
├── PolicyResult    # / RequirementResult; #to_h is the JSON contract
├── TTYFormatter
└── Policies::{GDPR, CCPA, LGPD, DPDP}
```

**Requirement kinds and statuses (D8):**

- *Checkable* — has `checks:` (scanner check ids, run through the Phase 1
  Runner against the live app) and/or `verify:` (a proc over app state, with
  an `evidence:` string saying what it inspects). All pass → `:met`; any fail
  → `:unmet`; only skips/errors in the way (e.g. production-only checks in
  dev) → `:unverified` with the reasons. Never guessed.
- *Attestable* — `:met` only via a valid attestation, and results carry the
  attester and date so reports render "attested by jane@corp.com on
  2026-07-01", visibly distinct from "verified". Missing or expired → `:unmet`.

**Scoring (D10):** per policy, `met / (met + unmet) × 100`; `:unverified`
excluded from the denominator but always listed. All-unverified → no score,
stated as such.

**Built-in policies:** GDPR (11 requirements) is the reference
implementation; CCPA, LGPD, and DPDP ship as focused initial sets (6–7 each).
Technical controls (security of processing, breach-detection trail,
data-minimizing logs) are checkable today; data-subject rights (erasure,
portability, consent) are attestable *now* and flip to checkable in Phase 6
when Consent/Retention give Forseti something to verify. Requirement wording
stays descriptive and neutral — Forseti summarizes controls, it does not
interpret law.

**The disclaimer is part of the output contract:** every report (TTY and
JSON) carries "technical evidence, not legal advice; a passing report does
not constitute or guarantee regulatory compliance." Removing it from a
formatter is a review-blocking change.

## 8. Performance

Evaluation is on-demand (rake task / CI), one scanner-check run per
referenced check plus a YAML read. Nothing in the request path.

## 9. Security implications

- Attestation files carry names/emails — that's the point (accountability),
  but reports quoting them are as sensitive as the scanner reports (README
  already covers artifact handling).
- `YAML.safe_load` with only Date permitted — attestations are data, never code.
- Overstated compliance is this feature's real risk; the unverified status,
  attested-vs-verified split, and hard-coded disclaimer are the mitigations.

## 10. Testing strategy

DSL and kind derivation; attestation loading/validity/expiry; evaluator
matrix (met/unmet/unverified × checkable/attestable, proc raising →
unverified); a consistency spec asserting every `checks:` id in every
built-in policy exists in the scanner registry; config validation
(`enable :nope` raises); TTY/JSON output incl. disclaimer; task smoke tests;
custom-policy definition. Fake contexts run as production so
production-only checks participate.

## 11. Documentation

README compliance section (disclaimer prominent); attestations.yml is
self-documenting via the generator; YARD on the DSL.

## 12. Implementation

Follows in this change set.
