# frozen_string_literal: true

module Forseti
  module Compliance
    # Terminal output for forseti:compliance. Attested requirements render
    # visibly differently from machine-verified ones (ADR 005 §7), and the
    # disclaimer is part of the output contract.
    class TTYFormatter
      # @param results [Array<Forseti::Compliance::PolicyResult>]
      def initialize(results, color: nil)
        @results = results
        @color = color.nil? ? Reporting::ANSI.auto? : color
      end

      # @return [String]
      def render
        sections = @results.map { |result| policy_section(result) }
        (sections + [paint(DISCLAIMER, :dim)]).join("\n")
      end

      private

      def policy_section(result)
        lines = ["#{paint(result.policy.name, :bold)} (#{result.policy.version})"]
        lines += result.requirement_results.map { |req| requirement_line(req) }
        lines << footer(result)
        "#{lines.join("\n")}\n"
      end

      def requirement_line(req)
        prefix = "  #{status_mark(req)} #{req.requirement.article.ljust(14)} #{req.requirement.title}"
        lines = ["#{prefix} #{status_label(req)}"]
        lines += req.evidence.map { |item| "      #{paint('•', :dim)} #{item}" } unless req.met?
        if req.unmet? && req.requirement.remediation
          lines << "      #{paint('↳', :cyan)} #{req.requirement.remediation}"
        end
        lines.join("\n")
      end

      def status_mark(req)
        case req.status
        when :met then paint("✔", :green)
        when :unmet then paint("✖", :red)
        else paint("?", :yellow)
        end
      end

      def status_label(req)
        if req.met? && req.attested?
          paint("[attested by #{req.attestation.attested_by} on #{req.attestation.attested_on}]", :cyan)
        elsif req.met?
          paint("[verified]", :green)
        elsif req.unverified?
          paint("[unverified]", :yellow)
        else
          paint("[unmet]", :red)
        end
      end

      def footer(result)
        score = result.score ? "#{result.score}/100" : "no score (nothing assessable)"
        counts = "#{result.met.size} met, #{result.unmet.size} unmet, #{result.unverified.size} unverified"
        "Compliance: #{paint(score, :bold)} — #{counts}"
      end

      def paint(text, color)
        Reporting::ANSI.paint(text, color, enabled: @color)
      end
    end
  end
end
