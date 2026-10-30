require "rails_helper"

RSpec.describe Ai::Gateway, type: :service do
  let(:user) { create(:user) }
  let(:analysable) { create(:service_request, customer: user) }
  let(:adapter) { Adapters::Ai::Fake.new }
  let(:vars) { { categories: "plumber: Plumber", language: "English", photo_note: "", description: "leaking tap" } }

  def run(**opts) = described_class.call(use_case: "triage", analysable:, user:, vars:, adapter:, **opts)

  it "stores the call with the prompt version, input hash and latency" do
    result = run
    expect(result.analysis).to have_attributes(status: "succeeded", provider: "fake", cached: false, model: "fake-rules-1")
    expect(result.analysis.input_hash).to match(/\A\h{64}\z/)
    expect(result.analysis.latency_ms).to be >= 0
  end

  it "keys the cache on the images too" do
    run(image_keys: [ "a" ])
    expect(run(image_keys: [ "b" ]).analysis.cached).to be(false)
    expect(run(image_keys: [ "a" ]).analysis.cached).to be(true)
  end

  it "only processes images for adapters that accept them" do
    images = -> { raise "should not be called" }
    expect { run(images:) }.not_to raise_error
  end

  it "stops calling a provider that keeps failing (circuit breaker)" do
    allow(adapter).to receive(:complete).and_raise(Adapters::Ai::Error.new(:provider_error))
    5.times { |i| expect { run(vars: vars.merge(description: "try #{i}")) }.to raise_error(ApplicationError) }
    expect(adapter).to have_received(:complete).exactly(5).times

    expect { run(vars: vars.merge(description: "again")) }.to raise_error(ApplicationError, /not available/)
    expect(adapter).to have_received(:complete).exactly(5).times

    # Half-open after the window: the next call goes through again.
    allow(adapter).to receive(:complete).and_call_original
    travel(2.minutes) { expect(run(vars: vars.merge(description: "later")).analysis.status).to eq("succeeded") }
  end

  it "enforces the per-user daily budget, not counting cache hits" do
    with_config(ai_user_daily_limit: 2)
    run
    run # cache hit
    run(vars: vars.merge(description: "second"))
    expect { run(vars: vars.merge(description: "third")) }.to raise_error(ApplicationError) { |e| expect(e.code).to eq("ai_budget_exceeded") }
    travel(25.hours) { expect { run(vars: vars.merge(description: "tomorrow")) }.not_to raise_error }
  end

  it "enforces the global daily budget as unavailable" do
    with_config(ai_global_daily_limit: 1)
    run
    expect { run(vars: vars.merge(description: "other")) }.to raise_error(ApplicationError) { |e| expect(e.code).to eq("ai_unavailable") }
  end

  it "keeps analyses append-only" do
    analysis = run.analysis
    expect { analysis.update!(status: "failed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
