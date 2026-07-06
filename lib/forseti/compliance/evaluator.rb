# frozen_string_literal: true

module Forseti
  module Compliance
    # Evaluates one policy against the booted app (ADR 005 §7). Statuses are
    # never guessed: checkable requirements whose evidence couldn't run (e.g.
    # production-only checks in development) come back :unverified with the
    # reasons, not :met.
    class Evaluator
      def initialize(policy, context:, attestations:)
        @policy = policy
        @context = context
        @attestations = attestations
      end

      # @return [Forseti::Compliance::PolicyResult]
      def evaluate
        results = @policy.requirements.map { |requirement| evaluate_requirement(requirement) }
        PolicyResult.new(@policy, results)
      end

      private

      def evaluate_requirement(requirement)
        if requirement.kind == :attestable
          evaluate_attestable(requirement)
        else
          evaluate_checkable(requirement)
        end
      end

      def evaluate_attestable(requirement)
        attestation = @attestations.for(@policy.key, requirement.key)

        if attestation&.valid?
          RequirementResult.new(requirement, status: :met, attestation: attestation,
                                             evidence: ["Attested by #{attestation.attested_by} " \
                                                        "on #{attestation.attested_on}"])
        elsif attestation&.expired?
          RequirementResult.new(requirement, status: :unmet,
                                             evidence: ["Attestation expired on #{attestation.expires_on}"])
        else
          RequirementResult.new(requirement, status: :unmet,
                                             evidence: ["No attestation in " \
                                                        "#{Forseti.config.compliance.attestations_path}"])
        end
      end

      def evaluate_checkable(requirement)
        verdicts = check_verdicts(requirement) + verify_verdicts(requirement)
        conclusive = verdicts.reject { |v| v[:status] == :neutral }

        evidence = verdicts.pluck(:evidence)
        evidence << "No applicable evidence could run" if conclusive.empty?
        RequirementResult.new(requirement, status: checkable_status(conclusive), evidence: evidence)
      end

      def checkable_status(conclusive)
        statuses = conclusive.pluck(:status)
        return :unmet if statuses.include?(:unmet)
        return :unverified if statuses.include?(:unverified) || statuses.empty?

        :met
      end

      def check_verdicts(requirement)
        requirement.checks.map do |check_id|
          check_class = Scanner.registry[check_id]
          next { status: :unverified, evidence: "Unknown scanner check #{check_id}" } if check_class.nil?

          result = run_check(check_class)
          { status: verdict_for(result), evidence: "#{check_id}: #{result.status} — #{result.message}" }
        end
      end

      def run_check(check_class)
        Scanner::Runner.new([check_class], context: @context, config: Forseti.config.scanner).run.first
      end

      def verdict_for(result)
        return :met if result.passed?
        return :unmet if result.failed?
        # A check that is moot for this app (e.g. audit.storage with a
        # non-database sink) is neutral evidence, not missing evidence.
        return :neutral if result.skipped? && result.skip_cause == :not_applicable

        :unverified # env-gated skip, config skip, or error — reason in evidence
      end

      def verify_verdicts(requirement)
        return [] unless requirement.verify_proc

        outcome = requirement.verify_proc.call
        [{ status: outcome ? :met : :unmet,
           evidence: "#{requirement.evidence}: #{outcome ? 'satisfied' : 'not satisfied'}" }]
      rescue StandardError => e
        [{ status: :unverified, evidence: "#{requirement.evidence}: could not verify (#{e.class})" }]
      end
    end
  end
end
