# frozen_string_literal: true

module Forseti
  module Compliance
    # The outcome of evaluating one requirement.
    class RequirementResult
      attr_reader :requirement, :status, :evidence, :attestation

      def initialize(requirement, status:, evidence: [], attestation: nil)
        @requirement = requirement
        @status = status
        @evidence = Array(evidence)
        @attestation = attestation
      end

      def met? = status == :met
      def unmet? = status == :unmet
      def unverified? = status == :unverified
      def attested? = !attestation.nil?

      def to_h
        {
          key: requirement.key,
          article: requirement.article,
          title: requirement.title,
          kind: requirement.kind,
          status: status,
          evidence: evidence,
          attestation: attestation&.to_h,
          remediation: unmet? ? requirement.remediation : nil
        }.compact
      end
    end
  end
end
