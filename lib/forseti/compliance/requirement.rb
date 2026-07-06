# frozen_string_literal: true

module Forseti
  module Compliance
    # One control within a policy. The kind is derived (ADR 005 §7):
    #
    # - **checkable** — has +checks+ (scanner check ids) and/or +verify+ (a
    #   proc over app state, described by +evidence+). Machine-verified.
    # - **attestable** — neither; only a valid human attestation satisfies it,
    #   and reports always say so.
    #
    # +or_attested: true+ (ADR 006 §7) makes a checkable requirement accept a
    # valid attestation as fallback when machine evidence doesn't satisfy it —
    # for controls apps may implement outside Forseti (e.g. an external CMP).
    # The report still says which one satisfied it.
    class Requirement
      attr_reader :key, :title, :article, :description, :checks, :verify_proc,
                  :evidence, :remediation

      def initialize(key:, title:, article:, description: nil, checks: [], verify: nil,
                     evidence: nil, remediation: nil, or_attested: false)
        @key = key.to_sym
        @title = title
        @article = article
        @description = description
        @checks = Array(checks).map(&:to_s).freeze
        @verify_proc = verify
        @evidence = evidence
        @remediation = remediation
        @or_attested = or_attested

        if verify && evidence.nil?
          raise ArgumentError,
                "Requirement #{key.inspect}: a verify: proc needs an evidence: string describing " \
                "what it inspects (transparency is the point)"
        end

        freeze
      end

      # @return [Symbol] :checkable or :attestable
      def kind
        checks.any? || verify_proc ? :checkable : :attestable
      end

      # Whether a valid attestation can satisfy this checkable requirement
      # when machine evidence doesn't.
      def or_attested?
        @or_attested
      end
    end
  end
end
