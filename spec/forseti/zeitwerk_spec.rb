# frozen_string_literal: true

RSpec.describe "Zeitwerk compliance" do
  it "eager loads the whole gem without naming errors" do
    # The gem's own loader only — eager_load_all would also force the
    # engine's app/models, which legitimately requires Active Record.
    expect { Forseti.eager_load! }.not_to raise_error
  end
end
