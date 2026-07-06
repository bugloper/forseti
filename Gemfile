# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "appraisal", "~> 2.5"
gem "rake", "~> 13.0"
# >= 7.1 (not ~> 8.0): rspec-rails 8 requires Rails 7.2+, and the Appraisal
# matrix still tests Rails 7.1, which resolves to rspec-rails 7.x.
gem "rspec-rails", ">= 7.1"
gem "rubocop", "~> 1.75"
gem "rubocop-performance", "~> 1.24"
gem "rubocop-rails", "~> 2.30"
gem "rubocop-rspec", "~> 3.5"
# For the spec:ar suite only — the gem itself never depends on Active Record
# (ADR 000 D2). Appraisals pin sqlite3 per Rails version (7.1 caps at 1.x).
gem "activerecord", ">= 7.1"
gem "sqlite3", ">= 1.7"

# For the spec:integrations suite only — Forseti detects the (archived)
# secure_headers gem at runtime but never depends on it (ADR 002 §5). This
# dev dependency lets the introspection contract be tested against the real
# gem instead of stubs (the get-vs-dup API guess already bit us once).
gem "secure_headers", ">= 6.5"
