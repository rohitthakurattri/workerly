require "rails_helper"

RSpec.describe Adapters::Ai::OpenAi do
  subject(:adapter) { described_class.new(api_key: "sk-test") }

  let(:url) { "https://api.openai.com/v1/chat/completions" }
  let(:args) do
    { use_case: "triage", system: "sys", user: "text", schema: { "type" => "object" }, model: "m", timeout: 8,
      images: [ { content_type: "image/jpeg", data: "QUJD" } ] }
  end
  let(:ok_body) do
    { model: "m-2026", usage: { prompt_tokens: 120, completion_tokens: 40 },
      choices: [ { message: { content: { category_slug: "plumber", confidence: 0.9 }.to_json } } ] }.to_json
  end

  it "sends a strict JSON-schema request with inline images and parses the answer" do
    stub = stub_request(:post, url).with(headers: { "Authorization" => "Bearer sk-test" }) do |req|
      body = JSON.parse(req.body)
      body["response_format"] == { "type" => "json_schema", "json_schema" => { "name" => "triage", "strict" => true, "schema" => { "type" => "object" } } } &&
        body.dig("messages", 1, "content", 1, "image_url", "url") == "data:image/jpeg;base64,QUJD"
    end.to_return(status: 200, body: ok_body)

    response = adapter.complete(**args)
    expect(stub).to have_been_requested
    expect(response).to have_attributes(output: { "category_slug" => "plumber", "confidence" => 0.9 }, model: "m-2026",
                                        input_tokens: 120, output_tokens: 40)
  end

  {
    -> { to_return(status: 429) } => "rate_limited",
    -> { to_return(status: 500) } => "provider_error",
    -> { to_timeout } => "timeout",
    -> { to_return(status: 200, body: { choices: [ { message: { refusal: "no" } } ] }.to_json) } => "refused",
    -> { to_return(status: 200, body: { choices: [ { message: { content: "not json" } } ] }.to_json) } => "invalid_output"
  }.each do |stubbing, code|
    it "raises #{code}" do
      stub_request(:post, url).instance_exec(&stubbing)
      expect { adapter.complete(**args) }.to raise_error(Adapters::Ai::Error) { |e| expect(e.code).to eq(code) }
    end
  end

  it "refuses to run without a key or model" do
    expect { described_class.new(api_key: nil).complete(**args) }.to raise_error(Adapters::Ai::Error, /not_configured|required/)
  end
end
