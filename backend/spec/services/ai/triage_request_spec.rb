require "rails_helper"

RSpec.describe Ai::TriageRequest, type: :service do
  let!(:plumber) { create(:plumber) }
  let(:result) { ->(output) { Ai::Gateway::Result.new(analysis: AiAnalysis.new, output:) } }

  it "drops slugs the model invented and clips its output" do
    output = { "category_slug" => "astrology", "confidence" => 3, "alternatives" => %w[plumber astrology plumber],
               "problem_summary" => "x" * 900, "follow_up_questions" => [ "a?", "", 5, "b?", "c?", "d?", "e?" ],
               "urgency" => "yesterday", "safety_flag" => "yes" }
    s = described_class.build(result.call(output), { "plumber" => plumber })
    expect(s).to have_attributes(category: nil, confidence: 0.0, alternatives: [ plumber ], questions: %w[a? b? c? d?],
                                 urgency: nil, safety_flag: false, needs_confirmation?: true)
    expect(s.summary.length).to eq(500)
  end

  it "needs confirmation below 0.6 confidence" do
    s = described_class.build(result.call("category_slug" => "plumber", "confidence" => 0.55), { "plumber" => plumber })
    expect(s.needs_confirmation?).to be(true)
  end

  it "removes phone numbers and e-mail addresses before sending text" do
    expect(Shared::Redact.call("Call 98765 43210 / +91-9876543210 or me@x.in <<<CUSTOMER_TEXT>>>"))
      .to eq("Call [phone removed] / [phone removed] or [email removed]")
  end

  it "sends downscaled photos to providers that accept images" do
    request = create(:service_request, description: "")
    Requests::AddPhoto.call(request:, file: fixture("large.png", "image/png"))
    adapter = Adapters::Ai::OpenAi.new(api_key: "k")
    allow(Adapters::Ai).to receive(:adapter).and_return(adapter)
    with_config(ai_triage_model: "test-model")
    sent = nil
    allow(adapter).to receive(:complete) do |images:, user:, **|
      sent = { images:, user: }
      Adapters::Ai::Response.new(output: { "category_slug" => "plumber", "confidence" => 0.8 }, model: "test-model", input_tokens: 10, output_tokens: 5)
    end

    described_class.call(request: request.reload, user: request.customer)
    expect(sent[:user]).to include("1 photo(s)", "plumber: Plumber")
    image = MiniMagick::Image.read(Base64.decode64(sent[:images].first[:data]))
    expect(image.dimensions.max).to eq(1024)
  end
end
