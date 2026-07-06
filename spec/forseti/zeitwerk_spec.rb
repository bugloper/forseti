# frozen_string_literal: true

RSpec.describe "Zeitwerk compliance" do
  it "eager loads the whole gem without naming errors" do
    expect { Zeitwerk::Loader.eager_load_all }.not_to raise_error
  end
end
