# frozen_string_literal: true

RSpec.describe Forseti::Reporting::ANSI do
  describe ".paint" do
    it "wraps text in escape codes when enabled and passes through when not" do
      expect(described_class.paint("hi", :red, enabled: true)).to eq("\e[31mhi\e[0m")
      expect(described_class.paint("hi", :red, enabled: false)).to eq("hi")
    end
  end

  describe ".severity_tag" do
    it "colors severities conventionally" do
      expect(described_class.severity_tag(:critical, enabled: true)).to eq("\e[31m[critical]\e[0m")
      expect(described_class.severity_tag(:medium, enabled: true)).to eq("\e[33m[medium]\e[0m")
      expect(described_class.severity_tag(:low, enabled: true)).to eq("\e[36m[low]\e[0m")
    end

    it "dims unknown severities rather than raising" do
      expect(described_class.severity_tag(:whatever, enabled: true)).to start_with("\e[2m")
    end
  end
end
