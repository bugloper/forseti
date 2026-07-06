# frozen_string_literal: true

require_relative "lib/forseti/version"

Gem::Specification.new do |spec|
  spec.name = "forseti"
  spec.version = Forseti::VERSION
  spec.authors = ["bugloper"]
  spec.email = ["bugloper@gmail.com"]

  spec.summary = "Security and compliance framework for Ruby on Rails."
  spec.description = <<~DESC.tr("\n", " ").strip
    Forseti unifies Rails security hardening, privacy protection, and regulatory
    compliance (GDPR, CCPA, LGPD, DPDP) behind one Rails-native, convention-over-configuration
    framework: security posture scanning and scoring, security headers, PII detection and
    redaction, audit trails, and consent and retention management.
  DESC
  spec.homepage = "https://github.com/bugloper/forseti"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["app/**/*", "lib/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  # Hard dependencies are deliberately minimal (ADR 000, D2): Active Record is
  # a soft dependency — Persist-tier modules check for it at activation time.
  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
