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
    ansi = Forseti::Reporting::ANSI
    Forseti::Scanner.registry.checks.each do |check|
      severity = ansi.paint("[#{check.severity}]".ljust(10),
                            ansi::SEVERITY_COLORS.fetch(check.severity, :dim))
      flags = check.production_only? ? ansi.paint("(production-only) ", :dim) : ""
      puts "#{check.id.ljust(32)} #{severity} #{flags}#{check.title}"
    end
  end

  namespace :retention do
    desc "Dry run: show what each retention policy would delete (deletes nothing)"
    task preview: :environment do
      results = Forseti::Retention.preview
      if results.empty?
        puts "No retention policies declared. Add config.retention.policy(...) to the initializer."
        next
      end

      results.each do |result|
        detail = result[:error] ? "ERROR: #{result[:error]}" : "#{result[:eligible]} eligible"
        puts "#{result[:policy].to_s.ljust(32)} #{detail}"
      end
    end

    desc "Prune all retention policies (schedule via cron/solid_queue; audits each run)"
    task run: :environment do
      results = Forseti::Retention.run
      if results.empty?
        puts "No retention policies declared. Add config.retention.policy(...) to the initializer."
        next
      end

      failed = false
      results.each do |result|
        detail = result[:error] ? "ERROR: #{result[:error]}" : "#{result[:deleted]} deleted"
        failed ||= result.key?(:error)
        puts "#{result[:policy].to_s.ljust(32)} #{detail}"
      end
      exit 1 if failed
    end
  end
end
