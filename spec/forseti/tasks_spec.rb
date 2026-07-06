# frozen_string_literal: true

require "rake"

RSpec.describe "forseti rake tasks" do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks unless Rake::Task.task_defined?("forseti:score")
  end

  after { Rake::Task.tasks.each(&:reenable) }

  it "prints the score" do
    output = capture_stdout { Rake::Task["forseti:score"].invoke }

    expect(output).to match(%r{\A\d+/100 \([A-F]\)$})
  end

  it "prints the JSON report" do
    output = capture_stdout { Rake::Task["forseti:report"].invoke }

    expect(JSON.parse(output)["schema_version"]).to eq(1)
  end

  it "lists registered checks" do
    output = capture_stdout { Rake::Task["forseti:checks"].invoke }

    expect(output).to include("security.csp")
    expect(output).to include("privacy.filter_parameters")
  end

  it "doctor exits non-zero when failures reach fail_on" do
    # The dummy app fails security.csp (:high), the default threshold.
    status = nil
    expect do
      Rake::Task["forseti:doctor"].invoke
    rescue SystemExit => e
      status = e.status
    end.to output(/forseti:doctor failed/).to_stderr.and output(/Forseti Doctor/).to_stdout

    expect(status).to eq(1)
  end

  it "doctor succeeds when fail_on is above the worst failure" do
    Forseti.config.scanner.fail_on = :critical

    output = capture_stdout { Rake::Task["forseti:doctor"].invoke }

    expect(output).to include("Forseti Doctor")
    expect(output).to include("✖ security.csp")
  end
end
