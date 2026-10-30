require "rails_helper"

RSpec.describe "OTP login", type: :request do
  let(:phone) { "+919876511111" }

  def verify(code, **extra) = post_json("/api/v1/auth/otp/verify", { phone:, code: }.merge(extra))

  describe "requesting a code" do
    it "sends the code by SMS in the DLT template format" do
      perform_enqueued_jobs { post_json("/api/v1/auth/otp", { phone: "9876511111" }) }

      expect(response).to have_http_status(:accepted)
      delivery = Adapters::Sms::Fake.deliveries.sole
      expect(delivery.to).to eq(phone)
      expect(delivery.body).to match(/\A\d{6} is your Workerly login code/).and match(/@workerly\.in #\d{6}\z/)
    end

    it "keeps codes and phone numbers out of logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      expect(filter.filter("phone" => "+919876511111", "code" => "123456", "mfa_token" => "x"))
        .to eq("phone" => "[FILTERED]", "code" => "[FILTERED]", "mfa_token" => "[FILTERED]")
      expect(Identity::SendOtpSmsJob.log_arguments?).to be(false)
    end

    it "never stores the code in plain text" do
      code = request_otp_code(phone)
      expect(OtpChallenge.last.code_digest).not_to include(code)
    end

    it "makes the caller wait 30 s between codes" do
      post_json("/api/v1/auth/otp", { phone: })
      post_json("/api/v1/auth/otp", { phone: })

      expect(response).to have_http_status(:too_many_requests)
      expect(error_code).to eq("otp_resend_too_soon")
      expect(response.headers["Retry-After"].to_i).to be_between(1, 30)
    end

    it "allows 3 codes per phone per 15 minutes" do
      3.times do |i|
        travel_to(i.minutes.from_now) { post_json("/api/v1/auth/otp", { phone: }) }
        expect(response).to have_http_status(:accepted)
      end
      travel_to(4.minutes.from_now) { post_json("/api/v1/auth/otp", { phone: }) }
      expect(error_code).to eq("otp_limit_reached")

      travel_to(16.minutes.from_now) { post_json("/api/v1/auth/otp", { phone: }) }
      expect(response).to have_http_status(:accepted)
    end

    it "invalidates the previous code when a new one is sent" do
      old_code = request_otp_code(phone)
      travel_to(1.minute.from_now) do
        request_otp_code(phone)
        verify(old_code)
      end
      expect(error_code).to eq("otp_incorrect")
    end

    it "requires a phone" do
      post_json("/api/v1/auth/otp", {})
      expect(response).to have_http_status(:bad_request)
      expect(error_code).to eq("parameter_missing")
    end
  end

  describe "verifying a code" do
    it "creates a customer on first login and sets an HttpOnly refresh cookie" do
      code = request_otp_code(phone)
      expect { verify(code) }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(User.last.roles).to eq([ "customer" ])
      set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
      expect(set_cookie).to match(/wk_rt=[^;]+; path=\/api\/v1\/auth;.*httponly/i).and match(/samesite=lax/i)
      expect(json["data"]).not_to have_key("refresh_token")
    end

    it "logs an existing user in without creating another" do
      create(:user, phone_e164: phone)
      code = request_otp_code(phone)
      expect { verify(code) }.not_to change(User, :count)
      expect(response).to have_http_status(:created)
    end

    it "accepts a code only once" do
      code = request_otp_code(phone)
      verify(code)
      verify(code)
      expect(error_code).to eq("otp_invalid_or_expired")
    end

    it "expires codes after 5 minutes" do
      code = request_otp_code(phone)
      travel_to(5.minutes.from_now + 1.second) { verify(code) }
      expect(error_code).to eq("otp_invalid_or_expired")
    end

    it "locks the code after 5 wrong attempts, even if the 6th is right" do
      code = request_otp_code(phone)
      wrong = code == "111111" ? "222222" : "111111"
      4.times { verify(wrong) }
      expect(json.dig("error", "details", "attempts_left")).to eq(1)
      verify(wrong)
      verify(code)
      expect(error_code).to eq("otp_invalid_or_expired")
    end

    it "starts as a worker when the worker app asks and the user is one" do
      create(:user, :worker, phone_e164: phone)
      verify(request_otp_code(phone), role: "worker")
      expect(json.dig("data", "active_role")).to eq("worker")
    end

    it "falls back to customer when the worker app asks but the user is not a worker yet" do
      verify(request_otp_code(phone), role: "worker")
      expect(json.dig("data", "active_role")).to eq("customer")
    end

    it "returns the refresh token in the body for native clients" do
      verify(request_otp_code(phone), token_delivery: "body")
      expect(json.dig("data", "refresh_token")).to be_present
      expect(refresh_cookie).to be_nil
    end

    it "refuses suspended accounts" do
      create(:user, :suspended, phone_e164: phone)
      verify(request_otp_code(phone))
      expect(response).to have_http_status(:forbidden)
      expect(error_code).to eq("account_suspended")
    end

    context "with scope=staff" do
      it "does not create users" do
        code = request_otp_code(phone)
        expect { verify(code, scope: "staff") }.not_to change(User, :count)
        expect(error_code).to eq("not_staff")
      end

      it "refuses customers" do
        create(:user, phone_e164: phone)
        verify(request_otp_code(phone), scope: "staff")
        expect(response).to have_http_status(:forbidden)
      end

      it "returns an MFA token instead of a session" do
        create(:user, :admin, phone_e164: phone)
        expect { verify(request_otp_code(phone), scope: "staff") }.not_to change(UserSession, :count)
        expect(json["data"]).to include("mfa_required" => true, "mfa_token" => be_present)
        expect(refresh_cookie("wk_rt_staff")).to be_nil
      end
    end

    it "rejects unknown scopes" do
      verify("123456", scope: "root")
      expect(error_code).to eq("invalid_scope")
    end
  end
end
