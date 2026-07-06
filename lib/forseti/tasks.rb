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

  desc "Evaluate enabled compliance policies (FORMAT=json for machine output)"
  task compliance: :environment do
    results = Forseti::Compliance.evaluate_enabled

    if results.empty?
      puts "No compliance policies enabled. Add e.g. `config.compliance.enable :gdpr` " \
           "to config/initializers/forseti.rb. Available: " \
           "#{Forseti::Compliance.registry.keys.sort.join(', ')}."
      next
    end

    if ENV["FORMAT"] == "json"
      puts JSON.pretty_generate(results.map(&:to_h))
    else
      puts Forseti::Compliance::TTYFormatter.new(results).render
    end

    if results.any? { |result| result.unmet.any? }
      $stdout.flush
      warn "\nforseti:compliance: unmet requirements present"
      exit 1
    end
  end

  desc "List all registered scanner checks"
  task checks: :environment do
    Forseti::Scanner.registry.checks.each do |check|
      flags = check.production_only? ? " (production-only)" : ""
      puts "#{check.id.ljust(32)} [#{check.severity}]#{flags} #{check.title}"
    end
  end
end
