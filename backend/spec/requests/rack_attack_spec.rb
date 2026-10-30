require "rails_helper"

RSpec.describe "Rack::Attack throttles", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  after { Rack::Attack.enabled = false }

  it "limits OTP requests per phone across different formats of the same number" do
    # Rack::Attack counts in fixed 15-minute buckets; start at the beginning of one.
    start = Time.zone.at((Time.now.to_i / 15.minutes) * 15.minutes + 1)
    # Spread across time so the DB resend rule doesn't fire first.
    %w[9876522222 +91\ 98765\ 22222 098765-22222].each_with_index do |phone, i|
      travel_to(start + (i * 31).seconds) { post_json("/api/v1/auth/otp", { phone: }) }
      expect(response).to have_http_status(:accepted)
    end
    travel_to(start + 100.seconds) { post_json("/api/v1/auth/otp", { phone: "9876522222" }) }

    expect(response).to have_http_status(:too_many_requests)
    expect(error_code).to eq("rate_limited")
  end

  it "limits OTP requests per IP" do
    10.times { |i| post_json("/api/v1/auth/otp", { phone: "98765330#{format('%02d', i)}" }) }
    post_json("/api/v1/auth/otp", { phone: "9876533099" })
    expect(response).to have_http_status(:too_many_requests)
  end
end
