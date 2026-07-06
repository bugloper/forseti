# frozen_string_literal: true

module Forseti
  module Reporting
    # Minimal ANSI coloring shared by Forseti's terminal output. Color is
    # dropped for non-TTY output and when NO_COLOR is set.
    module ANSI
      CODES = { red: 31, green: 32, yellow: 33, cyan: 36, dim: 2, bold: 1 }.freeze

      SEVERITY_COLORS = {
        critical: :red, high: :red, medium: :yellow, low: :cyan, info: :dim
      }.freeze

      module_function

      # @param text [Object]
      # @param color [Symbol] one of {CODES}
      # @param enabled [Boolean]
      # @return [String]
      def paint(text, color, enabled: auto?)
        return text.to_s unless enabled

        "\e[#{CODES.fetch(color)}m#{text}\e[0m"
      end

      # Renders a severity tag like "[high]" in its conventional color. Pad
      # before calling — escape codes break ljust on the result.
      #
      # @param severity [Symbol]
      # @return [String]
      def severity_tag(severity, enabled: auto?)
        paint("[#{severity}]", SEVERITY_COLORS.fetch(severity, :dim), enabled: enabled)
      end

      # @return [Boolean] whether stdout wants color
      def auto?
        $stdout.tty? && ENV["NO_COLOR"].nil?
      end
    end
  end
end
