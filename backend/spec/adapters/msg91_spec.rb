require "rails_helper"

RSpec.describe Adapters::Sms::Msg91 do
  let(:url) { "https://control.msg91.com/api/v5/flow" }
  let(:env) { { "MSG91_TEMPLATE_OTP" => "tmpl-otp", "MSG91_TEMPLATE_LEAD_NEW" => "tmpl-lead" } }
  let(:adapter) { described_class.new(auth_key: "auth-123", sender: nil, env:) }
  let(:otp) { Adapters::Sms.otp_message("482913") }

  def error_code
    yield
    nil
  rescue Adapters::Sms::Error => e
    e.code
  end

  it "sends the registered template with its variables to the number without the plus" do
    stub = stub_request(:post, url)
           .with(headers: { "authkey" => "auth-123", "Content-Type" => "application/json" },
                 body: { template_id: "tmpl-otp", short_url: "0", recipients: [ { mobiles: "919814000014", code: "482913" } ] }.to_json)
           .to_return(status: 200, body: { type: "success", message: "3b6f8e2a" }.to_json)

    expect(adapter.deliver(to: "+919814000014", message: otp)).to be(true)
    expect(stub).to have_been_requested
  end

  it "passes clipped variables and the sender when one is set" do
    stub = stub_request(:post, url).with do |req|
      body = JSON.parse(req.body)
      body["sender"] == "WRKRLY" && body["recipients"] == [ { "mobiles" => "919814000014", "category" => "Plumber", "locality" => "Sector 70, Mohali, near the gu" } ]
    end.to_return(status: 200, body: { type: "success", message: "x" }.to_json)

    message = Adapters::Sms.message(:lead_new, category: "Plumber", locality: "Sector 70, Mohali, near the gurudwara")
    described_class.new(auth_key: "auth-123", sender: "WRKRLY", env:).deliver(to: "+919814000014", message:)
    expect(stub).to have_been_requested
  end

  it "says what is missing before calling MSG91" do
    expect(error_code { described_class.new(auth_key: nil, env:).deliver(to: "+919814000014", message: otp) }).to eq("not_configured")
    expect(error_code { adapter.deliver(to: "+919814000014", message: Adapters::Sms.message(:worker_approved)) }).to eq("not_configured")
    expect(error_code { adapter.deliver(to: "+14155550100", message: otp) }).to eq("invalid_number")
    expect(WebMock).not_to have_requested(:post, url)
  end

  it "doesn't retry what MSG91 refused, and retries what may pass next time" do
    stub_request(:post, url).to_return(status: 401, body: { type: "error", message: "Authentication failure" }.to_json)
    expect(error_code { adapter.deliver(to: "+919814000014", message: otp) }).to eq("rejected")
    expect(Adapters::Sms::Error.new(:rejected)).not_to be_retryable

    { -> { to_return(status: 503) } => "provider_error", -> { to_return(status: 429) } => "provider_error",
      -> { to_timeout } => "timeout", -> { to_raise(SocketError) } => "network",
      -> { to_return(status: 200, body: "<html>") } => "provider_error" }.each do |stubbing, code|
      WebMock.reset!
      stub_request(:post, url).instance_exec(&stubbing)
      expect(error_code { adapter.deliver(to: "+919814000014", message: otp) }).to eq(code)
      expect(Adapters::Sms::Error.new(code)).to be_retryable
    end
  end

  it "lists templates with no MSG91 id" do
    expect(described_class.missing_templates(env)).to eq(%i[quote_accepted worker_approved worker_changes_requested worker_rejected])
  end
end

RSpec.describe Adapters::Sms do
  it "renders each registered template from exactly its declared variables" do
    described_class.templates.each_value do |t|
      placeholders = t.text.scan(/%\{(\w+)\}/).flatten.map(&:to_sym).uniq
      expect(placeholders.sort).to eq(t.vars.sort), "#{t.key}: text uses #{placeholders}, declares #{t.vars}"
    end
    expect(described_class.otp_message("123456").body).to start_with("123456 is your Workerly login code.").and end_with("@workerly.in #123456")
    expect { described_class.message(:lead_new, category: "Plumber") }.to raise_error(ArgumentError, /takes/)
    expect { described_class.message(:nope) }.to raise_error(ArgumentError, /Unknown SMS template/)
  end

  it "keeps variables within DLT's 30-character limit" do
    m = described_class.message(:quote_accepted, category: "Appliance repair", locality: "x" * 50)
    expect(m.vars[:locality].length).to eq(30)
  end
end
