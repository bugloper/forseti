# frozen_string_literal: true

RSpec.describe Forseti::Security::Middleware do
  def app_returning(headers)
    ->(_env) { [200, headers, ["body"]] }
  end

  def response_headers(initial_headers)
    _status, headers, _body = described_class.new(app_returning(initial_headers)).call({})
    headers
  end

  def header(headers, name)
    headers.find { |key, _| key.casecmp?(name) }&.last
  end

  let(:html_headers) { { "Content-Type" => "text/html; charset=utf-8" } }

  context "when nothing is enabled" do
    it "leaves the response untouched" do
      headers = response_headers(html_headers.dup)

      expect(headers.keys).to contain_exactly("Content-Type")
    end
  end

  context "with headers_mode :enforce" do
    before { Forseti.config.security.headers_mode = :enforce }

    it "fills the missing baseline headers" do
      headers = response_headers(html_headers.dup)

      expect(header(headers, "X-Content-Type-Options")).to eq("nosniff")
      expect(header(headers, "X-Frame-Options")).to eq("SAMEORIGIN")
      expect(header(headers, "Referrer-Policy")).to eq("strict-origin-when-cross-origin")
      expect(header(headers, "X-Permitted-Cross-Domain-Policies")).to eq("none")
    end

    it "never overrides headers the app already sets, regardless of case" do
      headers = response_headers(html_headers.merge("x-frame-options" => "ALLOWALL"))

      expect(header(headers, "X-Frame-Options")).to eq("ALLOWALL")
      expect(headers.keys.count { |k| k.casecmp?("X-Frame-Options") }).to eq(1)
    end

    it "uses the configured dials" do
      Forseti.config.security.frame_options = "DENY"
      Forseti.config.security.referrer_policy = "no-referrer"

      headers = response_headers(html_headers.dup)

      expect(header(headers, "X-Frame-Options")).to eq("DENY")
      expect(header(headers, "Referrer-Policy")).to eq("no-referrer")
    end
  end

  context "with csp_mode :report" do
    before { Forseti.config.security.csp_mode = :report }

    it "adds a report-only CSP to HTML responses" do
      headers = response_headers(html_headers.dup)

      expect(header(headers, "Content-Security-Policy-Report-Only"))
        .to include("default-src 'self'")
      expect(header(headers, "Content-Security-Policy")).to be_nil
    end

    it "skips non-HTML responses" do
      headers = response_headers({ "Content-Type" => "application/json" })

      expect(header(headers, "Content-Security-Policy-Report-Only")).to be_nil
    end

    it "steps aside when the app already sends a CSP" do
      headers = response_headers(html_headers.merge("content-security-policy" => "default-src 'none'"))

      expect(header(headers, "Content-Security-Policy-Report-Only")).to be_nil
    end

    it "appends the report-uri when configured" do
      Forseti.config.security.csp_report_uri = "https://csp.example.com/r"

      headers = response_headers(html_headers.dup)

      expect(header(headers, "Content-Security-Policy-Report-Only"))
        .to end_with("report-uri https://csp.example.com/r")
    end
  end

  context "with csp_mode :enforce" do
    before { Forseti.config.security.csp_mode = :enforce }

    it "sends the enforcing header" do
      headers = response_headers(html_headers.dup)

      expect(header(headers, "Content-Security-Policy")).to include("object-src 'none'")
      expect(header(headers, "Content-Security-Policy-Report-Only")).to be_nil
    end
  end
end
