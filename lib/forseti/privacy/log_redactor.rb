# frozen_string_literal: true

module Forseti
  module Privacy
    # Formatter decorator that detects (or redacts) PII in formatted log lines
    # (ADR 003 §7). Two invariants:
    #
    # 1. **Fail-open.** Any internal error returns the original line — a
    #    redactor bug must never eat logs. Missed redactions are what :report
    #    mode exists to find.
    # 2. **No values leak sideways.** The pii_detected.forseti payload carries
    #    type keys only, never matched values.
    class LogRedactor
      EVENT = "pii_detected.forseti"
      GUARD = :forseti_log_redactor

      # Wraps the logger's formatter (idempotently). BroadcastLogger
      # propagates formatter= to every sink.
      #
      # @param logger [Logger, ActiveSupport::BroadcastLogger]
      # @return [void]
      def self.install(logger)
        return if logger.formatter.is_a?(self)

        logger.formatter = new(logger.formatter || ::Logger::Formatter.new)
      end

      # @param formatter [#call] the original formatter
      def initialize(formatter)
        @formatter = formatter
      end

      def call(severity, time, progname, message)
        line = @formatter.call(severity, time, progname, message)
        return line unless line.is_a?(String)

        process(line)
      end

      private

      def process(line)
        # The guard breaks recursion when a pii_detected subscriber logs.
        return line if Thread.current[GUARD]

        Thread.current[GUARD] = true
        begin
          redact(line)
        rescue StandardError
          line
        ensure
          Thread.current[GUARD] = false
        end
      end

      def redact(line)
        config = Forseti.config.privacy
        detected = []

        result = redactable_types(config).reduce(line) do |current, type|
          if config.log_redaction_mode == :enforce
            redact_matches(current, type, detected)
          else
            detected << type.key if type.matches_value?(current)
            current
          end
        end

        instrument(detected) if detected.any?
        result
      end

      def redact_matches(line, type, detected)
        line.gsub(type.value_pattern) do |match|
          next match unless type.valid_match?(match)

          detected << type.key
          "[REDACTED:#{type.key}]"
        end
      end

      def redactable_types(config)
        config.redact_types.filter_map { |key| PII[key] }.select(&:value_pattern)
      end

      def instrument(detected)
        ActiveSupport::Notifications.instrument(EVENT, types: detected.uniq, source: :log)
      end
    end
  end
end
