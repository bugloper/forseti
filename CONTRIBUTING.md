# Contributing to Forseti

Thank you for helping make Rails apps secure and privacy-compliant by default.

## Design-first workflow

Forseti is design-first: **no feature is implemented before its design doc.**
Every feature walks these steps, recorded as a numbered ADR in
[docs/design](docs/design):

1. Define the problem.
2. Explain how Rails currently addresses it.
3. Identify limitations.
4. Explain why Forseti should provide additional functionality.
5. Explore alternative designs and their trade-offs.
6. Propose the public API.
7. Design the internal architecture.
8. Consider performance implications.
9. Consider security implications.
10. Plan the testing strategy.
11. Outline the documentation.
12. Only then implement.

Small fixes and refactors don't need an ADR; anything adding or changing
public API does.

## Ground rules

- **No monkey patching.** Integration goes through Railtie initializers,
  middleware, `ActiveSupport.on_load` hooks, and opt-in concerns. A PR that
  reopens a Rails class needs an ADR justifying it.
- **Installing must be a no-op.** New enforcing behavior defaults to `:off`
  or `:report`, and stricter defaults ship behind a new defaults version
  (see ADR 000, D3/D4).
- **Prefer existing Rails APIs** before introducing custom abstractions.
- **Compliance wording:** Forseti "helps you meet" requirements. Never write
  docs, messages, or report output claiming it "makes you compliant."
- Every public method gets YARD documentation. Every change gets tests.

## Development

```bash
bundle install
bundle exec rake            # specs + RuboCop
bundle exec appraisal install
bundle exec appraisal rspec # full Rails version matrix
```

The spec suite boots an Active-Record-free dummy app (`spec/dummy`) on
purpose: Forseti's core must not require Active Record. Don't add it there —
persistence-tier features will get their own AR-enabled harness.

## Releasing

Maintainers only: update CHANGELOG.md, bump `Forseti::VERSION`, then
`bundle exec rake release`.
