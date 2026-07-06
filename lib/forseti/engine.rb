# frozen_string_literal: true

module Forseti
  # Forseti's Rails engine.
  #
  # Deliberately inert (ADR 000, D2/D3): requiring the gem changes nothing
  # about application behavior. Persist-tier features (models, migrations,
  # routes) only activate through explicit generators, and enforcement only
  # through explicit configuration.
  class Engine < ::Rails::Engine
    isolate_namespace Forseti

    rake_tasks do
      load File.expand_path("tasks.rb", __dir__)
    end
  end
end
