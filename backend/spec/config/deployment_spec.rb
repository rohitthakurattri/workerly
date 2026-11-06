require "rails_helper"

RSpec.describe "Deployment safety" do
  def config(**overrides) = Workerly::Config.new(**Workerly.config.to_h.merge(overrides))

  it "refuses to boot production on fake SMS or payments, but lets staging and development" do
    expect { Workerly.check_deployment!(config(deploy_env: "production"), production: true) }
      .to raise_error(/fake adapters: SMS_ADAPTER, PAYMENT_ADAPTER/)
    expect { Workerly.check_deployment!(config(deploy_env: "production", sms_adapter: "msg91", payment_adapter: "razorpay", razorpay_key_id: nil), production: true) }
      .to raise_error(/needs RAZORPAY_KEY_ID/)
    expect { Workerly.check_deployment!(config(deploy_env: "production", sms_adapter: "msg91", payment_adapter: "razorpay", razorpay_key_id: "rzp_live_x"), production: true) }
      .not_to raise_error
    expect { Workerly.check_deployment!(config(deploy_env: "staging"), production: true) }.not_to raise_error
    expect { Workerly.check_deployment!(config, production: false) }.not_to raise_error
  end

  it "sends locked-down security headers on every API response" do
    expect(ActionDispatch::Response.default_headers).to include(
      "X-Content-Type-Options" => "nosniff", "X-Frame-Options" => "DENY", "Referrer-Policy" => "no-referrer",
      "Content-Security-Policy" => "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
    )
  end
end
