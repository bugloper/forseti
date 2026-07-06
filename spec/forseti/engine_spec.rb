# frozen_string_literal: true

RSpec.describe Forseti::Engine do
  it "is a Rails engine" do
    expect(described_class.ancestors).to include(Rails::Engine)
  end

  it "isolates the Forseti namespace" do
    expect(described_class.isolated?).to be(true)
  end

  it "boots without Active Record loaded (soft dependency)" do
    expect(defined?(ActiveRecord)).to be_nil
  end
end
