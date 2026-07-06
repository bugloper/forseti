# frozen_string_literal: true

module Forseti
  module Reporting
    module Formatters
      # Human-readable terminal output for forseti:doctor. Failures render
      # first with remediation; passes, skips, and errors follow. Color is
      # dropped for non-TTY output and when NO_COLOR is set.
      class TTY
        COLORS = { red: 31, green: 32, yellow: 33, cyan: 36, dim: 2, bold: 1 }.freeze

        # @param report [Forseti::Reporting::Report]
        # @param color [Boolean, nil] override auto-detection
        def initialize(report, color: nil)
          @report = report
          @color = color.nil? ? auto_color? : color
        end

        # @return [String]
        def render
          [header, failures_section, errors_section, passes_section, skips_section, footer]
            .compact.join("\n")
        end

        private

        attr_reader :report

        def header
          <<~HEADER
            #{paint('Forseti Doctor', :bold)} — security posture for #{report.context.app_name} (#{report.context.env})
            Ruby #{RUBY_VERSION} · Rails #{Rails.version} · Forseti #{Forseti::VERSION}
          HEADER
        end

        def failures_section
          ordered = report.failed.sort_by { |result| -Scanner::Severity.weight(result.severity) }
          section("Failures", ordered.flat_map { |result| failure_lines(result) })
        end

        def failure_lines(result)
          [
            "  #{paint('✖', :red)} #{result.id.ljust(32)} #{result.message} #{paint("[#{result.severity}]", :red)}",
            *result.details.map { |detail| "      #{paint('•', :dim)} #{detail}" },
            "      #{paint('↳', :cyan)} #{result.check.remediation}"
          ]
        end

        def errors_section
          lines = report.errored.map do |result|
            "  #{paint('!', :yellow)} #{result.id.ljust(32)} #{result.message}"
          end
          section("Check errors (excluded from score, please report)", lines)
        end

        def passes_section
          lines = report.passed.map do |result|
            "  #{paint('✔', :green)} #{result.id.ljust(32)} #{result.message}"
          end
          section("Passed", lines)
        end

        def skips_section
          lines = report.skipped.map do |result|
            paint("  ↷ #{result.id.ljust(32)} #{result.message}", :dim)
          end
          section("Skipped", lines)
        end

        def section(heading, lines)
          return if lines.empty?

          (["#{paint(heading, :bold)}:"] + lines).join("\n") << "\n"
        end

        def footer
          score = report.score
          counts = "#{report.passed.size} passed, #{report.failed.size} failed, #{report.skipped.size} skipped"
          categories = score.by_category.map { |category, value| "#{category} #{value}" }.join(" · ")

          summary = "Score: #{paint("#{score.value}/100 (#{score.grade})", grade_color(score))} — #{counts}"
          categories.empty? ? summary : "#{summary}\n#{paint(categories, :dim)}"
        end

        def grade_color(score)
          case score.grade
          when "A", "B" then :green
          when "C" then :yellow
          else :red
          end
        end

        def paint(text, color)
          return text unless @color

          "\e[#{COLORS.fetch(color)}m#{text}\e[0m"
        end

        def auto_color?
          $stdout.tty? && ENV["NO_COLOR"].nil?
        end
      end
    end
  end
end
