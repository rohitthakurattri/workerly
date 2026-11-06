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

  describe "#transcribe" do
    let(:stt_url) { "https://api.openai.com/v1/audio/transcriptions" }
    let(:stt_args) { { audio: "OPUSBYTES", content_type: "audio/webm", language: "hi", prompt: "plumber, geyser", model: "stt-1", timeout: 30 } }

    it "uploads the audio as multipart with the language hint and reads text and billed seconds" do
      stub = stub_request(:post, stt_url).with(headers: { "Authorization" => "Bearer sk-test" }) do |req|
        req.headers["Content-Type"].start_with?("multipart/form-data") &&
          req.body.include?('filename="voice-note.webm"') && req.body.include?("OPUSBYTES") &&
          req.body.match?(/name="language"\r\n\r\nhi/) && req.body.match?(/name="model"\r\n\r\nstt-1/)
      end.to_return(status: 200, body: { text: "नल लीक है", usage: { type: "duration", seconds: 7 } }.to_json)

      response = adapter.transcribe(**stt_args)
      expect(stub).to have_been_requested
      expect(response).to have_attributes(output: { "text" => "नल लीक है", "language" => "hi" }, model: "stt-1", audio_seconds: 7)
    end

    it "needs a key and a model, and maps provider failures" do
      expect { described_class.new(api_key: nil).transcribe(**stt_args) }.to raise_error(Adapters::Ai::Error) { |e| expect(e.code).to eq("not_configured") }
      stub_request(:post, stt_url).to_return(status: 429)
      expect { adapter.transcribe(**stt_args) }.to raise_error(Adapters::Ai::Error) { |e| expect(e.code).to eq("rate_limited") }
      stub_request(:post, stt_url).to_return(status: 200, body: { nope: 1 }.to_json)
      expect { adapter.transcribe(**stt_args) }.to raise_error(Adapters::Ai::Error) { |e| expect(e.code).to eq("invalid_output") }
    end
  end
end
