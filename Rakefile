# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

# Two suites, one process each (ADR 004 §7): the main suite proves the gem
# works without Active Record; spec:ar loads AR standalone for Persist-tier
# specs.
RSpec::Core::RakeTask.new(:spec) do |task|
  task.exclude_pattern = "spec/ar/**/*_spec.rb"
end
RSpec::Core::RakeTask.new("spec:ar") do |task|
  task.rspec_opts = "--options .rspec-ar"
  task.pattern = "spec/ar/**/*_spec.rb"
end

RuboCop::RakeTask.new

task default: ["spec", "spec:ar", "rubocop"]
