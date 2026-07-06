# frozen_string_literal: true

module Forseti
  module Scanner
    # Base class for scanner checks (ADR 001 §6).
    #
    # Subclasses declare metadata and implement {#call}, returning a result
    # built with {#pass}, {#fail_with}, or {#skip}:
    #
    #   class Csp < Forseti::Scanner::Check
    #     id          "security.csp"
    #     severity    :high
    #     title       "Content Security Policy"
    #     remediation "Define a policy in config/initializers/content_security_policy.rb."
    #
    #     def call
    #       context.config.content_security_policy ? pass("CSP configured") : fail_with("No CSP configured")
    #     end
    #   end
    #
    # Checks are read-only by contract: they inspect {#context}, never mutate
    # application state, and never include secret values in messages — only
    # presence or absence.
    class Check
      class << self
        # Each DSL method is a combined reader/writer: with an argument it
        # declares the value, without it returns it.

        def id(value = nil)
          value.nil? ? @id : @id = value.to_s
        end

        def severity(value = nil)
          value.nil? ? @severity : @severity = Severity.validate!(value)
        end

        def title(value = nil)
          value.nil? ? @title : @title = value
        end

        def description(value = nil)
          value.nil? ? @description : @description = value
        end

        def remediation(value = nil)
          value.nil? ? @remediation : @remediation = value
        end

        # Marks the check as only meaningful in production-like environments
        # (ADR 001 §7, environment honesty). The runner reports it as skipped
        # elsewhere.
        def production_only(value = true) # rubocop:disable Style/OptionalBooleanParameter
          @production_only = value
        end

        def production_only?
          !!@production_only
        end

        # The category used for score grouping — the id's first segment.
        #
        # @return [String] e.g. "security"
        def category
          id.to_s.split(".").first
        end
      end

      # @return [Forseti::Scanner::Context]
      attr_reader :context

      def initialize(context)
        @context = context
      end

      # Whether the check is meaningful for this application at all (beyond
      # environment gating). Override together with {#not_applicable_reason}.
      def applies?
        true
      end

      # @return [String] shown on results skipped because {#applies?} is false
      def not_applicable_reason
        "Not applicable to this application"
      end

      # @abstract
      # @return [Forseti::Scanner::Result]
      def call
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end

      private

      def pass(message, details: [])
        Result.new(check: self.class, status: :passed, message: message, details: details)
      end

      def fail_with(message, details: [])
        Result.new(check: self.class, status: :failed, message: message, details: details)
      end

      def skip(reason)
        Result.new(check: self.class, status: :skipped, message: reason)
      end
    end
  end
end
