# frozen_string_literal: true

namespace :forseti do
  desc "Scan the app's security posture and print a scored, actionable report"
  task doctor: :environment do
    report = Forseti::Scanner.run
    puts Forseti::Reporting::Formatters::TTY.new(report).render

    threshold = Forseti.config.scanner.fail_on
    if report.failing?(threshold)
      $stdout.flush # keep report/verdict ordering stable when piped
      warn "\nforseti:doctor failed: findings at or above severity :#{threshold} " \
           "(tune with config.scanner.fail_on)"
      exit 1
    end
  end

  desc "Print the security score (0-100 and grade)"
  task score: :environment do
    score = Forseti::Scanner.run.score
    puts "#{score.value}/100 (#{score.grade})"
  end

  desc "Print the full scan report as JSON"
  task report: :environment do
    puts Forseti::Reporting::Formatters::JSON.new(Forseti::Scanner.run).render
  end

  desc "List all registered scanner checks"
  task checks: :environment do
    Forseti::Scanner.registry.checks.each do |check|
      flags = check.production_only? ? " (production-only)" : ""
      puts "#{check.id.ljust(32)} [#{check.severity}]#{flags} #{check.title}"
    end
  end
end
