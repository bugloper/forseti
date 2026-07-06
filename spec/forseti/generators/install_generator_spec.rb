# frozen_string_literal: true

require "tmpdir"
require "generators/forseti/install/install_generator"

RSpec.describe Forseti::Generators::InstallGenerator do
  it "creates a valid initializer with everything opt-in" do
    Dir.mktmpdir do |dir|
      quietly { described_class.start([], destination_root: dir) }
      initializer = File.join(dir, "config/initializers/forseti.rb")

      content = File.read(initializer)
      expect(content).to include('config.defaults = "1.0"')
      expect(content).to include("# config.security.enable!")
      # The template must parse and only pin defaults — no enforcement on install.
      expect { eval(content) }.not_to raise_error # rubocop:disable Security/Eval
      expect(Forseti.config.security.active?).to be(false)
    end
  end

  def quietly(&)
    capture_stdout(&)
  end
end
