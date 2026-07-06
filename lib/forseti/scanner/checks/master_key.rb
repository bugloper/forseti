# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class MasterKey < Check
        TARGET = "config/master.key"

        id          "security.master_key"
        severity    :critical
        title       "Credentials master key kept out of git"
        description "config/master.key decrypts all Rails credentials; committing it publishes every secret."
        remediation "Add `/config/master.key` to .gitignore and rotate credentials if it was ever committed."

        def applies?
          context.root.join(TARGET).exist? && context.root.join(".git").exist?
        end

        def not_applicable_reason
          "No config/master.key in a git repository"
        end

        def call
          if ignored?
            pass("config/master.key is covered by .gitignore")
          else
            fail_with("config/master.key is not matched by any .gitignore pattern — it can be committed")
          end
        end

        private

        def ignored?
          gitignore = context.root.join(".gitignore")
          return false unless gitignore.exist?

          gitignore.read.each_line.map(&:strip).any? { |pattern| matches_target?(pattern) }
        end

        def matches_target?(pattern)
          return false if pattern.empty? || pattern.start_with?("#")

          normalized = pattern.delete_prefix("/").delete_suffix("/")
          # Approximates gitignore semantics: exact path match, or a bare
          # pattern (e.g. *.key) matching at any depth via the basename.
          File.fnmatch?(normalized, TARGET) ||
            (normalized.exclude?("/") && File.fnmatch?(normalized, File.basename(TARGET)))
        end
      end
    end
  end
end
