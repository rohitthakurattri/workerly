require "swagger_helper"

# Happy paths and main errors for each auth endpoint; generates swagger/v1/openapi.yaml.
# Edge cases live in the sibling *_spec.rb files.
RSpec.describe "Auth API", type: :request do
  let(:phone) { "+919876500001" }

  path "/api/v1/auth/otp" do
    post "Send a login code by SMS" do
      tags "Auth"
      consumes "application/json"
      parameter name: :body, in: :body, schema: { type: :object, required: %w[phone], properties: { phone: { type: :string, example: "9876543210" } } }

      response "202", "code sent" do
        let(:body) { { phone: "98765 00001" } }
        schema type: :object, properties: { data: { type: :object, properties: { phone: { type: :string }, expires_in: { type: :integer }, resend_after: { type: :integer } } } }
        run_test! do
          expect(json["data"]).to include("phone" => "+91******0001", "expires_in" => 300)
          expect(Identity::SendOtpSmsJob).to have_been_enqueued.with(phone, a_string_matching(/\A\d{6}\z/))
        end
      end

      response "422", "invalid phone" do
        let(:body) { { phone: "12345" } }
        schema "$ref" => "#/components/schemas/error"
        run_test! { expect(error_code).to eq("invalid_phone") }
      end
    end
  end

  path "/api/v1/auth/otp/verify" do
    post "Verify a login code" do
      tags "Auth"
      consumes "application/json"
      description "scope=consumer (default) returns a session and sets the HttpOnly `wk_rt` cookie. scope=staff returns an MFA token for /auth/totp."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[phone code],
        properties: { phone: { type: :string }, code: { type: :string }, scope: { type: :string, enum: %w[consumer staff] },
                      role: { type: :string, enum: %w[customer worker] }, token_delivery: { type: :string, enum: %w[cookie body] } }
      }

      response "201", "logged in" do
        let(:body) { { phone:, code: request_otp_code(phone) } }
        schema "$ref" => "#/components/schemas/auth_session"
        run_test! { expect(json.dig("data", "active_role")).to eq("customer") }
      end

      response "200", "staff: TOTP required" do
        before { create(:user, :admin, phone_e164: phone) }
        let(:body) { { phone:, code: request_otp_code(phone), scope: "staff" } }
        run_test! { expect(json["data"]).to include("mfa_required" => true) }
      end

      response "422", "wrong code" do
        let(:body) { request_otp_code(phone) && { phone:, code: "000000" } }
        schema "$ref" => "#/components/schemas/error"
        before { allow(SecureRandom).to receive(:random_number).and_return(123_456) }
        run_test! { expect(error_code).to eq("otp_incorrect") }
      end
    end
  end

  path "/api/v1/auth/totp" do
    post "Staff second factor" do
      tags "Auth"
      consumes "application/json"
      parameter name: :body, in: :body, schema: { type: :object, required: %w[mfa_token code], properties: { mfa_token: { type: :string }, code: { type: :string }, role: { type: :string } } }

      let(:admin) { create(:user, :admin) }

      response "201", "staff session started" do
        let(:body) { { mfa_token: Identity::Tokens.mfa_token(user: admin), code: ROTP::TOTP.new(admin.totp_secret).now } }
        schema "$ref" => "#/components/schemas/auth_session"
        run_test! { expect(json.dig("data", "session", "scope")).to eq("staff") }
      end

      response "401", "wrong code" do
        let(:body) { { mfa_token: Identity::Tokens.mfa_token(user: admin), code: "000000" } }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Rotate the refresh token and get a new access token" do
      tags "Auth"
      consumes "application/json"
      description "Reads the refresh cookie for the given scope (or `refresh_token` with token_delivery=body). Reusing a rotated token revokes the session."
      parameter name: :Origin, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, properties: { scope: { type: :string }, role: { type: :string }, token_delivery: { type: :string }, refresh_token: { type: :string } } }
      let(:Origin) { AuthHelpers::ORIGIN }

      response "200", "rotated" do
        let(:issued) { Identity::Sessions.start(user: create(:user), scope: "consumer") }
        let(:body) { { token_delivery: "body", refresh_token: issued.refresh_token } }
        schema "$ref" => "#/components/schemas/auth_session"
        run_test! { expect(json.dig("data", "refresh_token")).not_to eq(issued.refresh_token) }
      end

      response "401", "invalid token" do
        let(:body) { { token_delivery: "body", refresh_token: "nope" } }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end
  end

  path "/api/v1/auth/switch_role" do
    post "Act as another role in the same session" do
      tags "Auth"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, required: %w[role], properties: { role: { type: :string } } }
      let(:user) { create(:user, :worker) }
      let(:Authorization) { auth_headers_for(user)["Authorization"] }

      response "200", "switched" do
        let(:body) { { role: "worker" } }
        schema "$ref" => "#/components/schemas/auth_session"
        run_test! { expect(json.dig("data", "active_role")).to eq("worker") }
      end

      response "403", "role not held" do
        let(:body) { { role: "admin" } }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end
  end

  path "/api/v1/auth/session" do
    delete "Log out (revokes the session and all its refresh tokens)" do
      tags "Auth"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }
      let(:Authorization) { auth_headers_for(create(:user))["Authorization"] }

      response "204", "logged out" do
        run_test!
      end
    end
  end

  path "/api/v1/me" do
    get "Current user" do
      tags "Me"
      security [ bearer: [] ]
      parameter name: :Authorization, in: :header, schema: { type: :string }

      response "200", "ok" do
        let(:Authorization) { auth_headers_for(create(:user, :worker), role: "worker")["Authorization"] }
        run_test! do
          expect(json["data"]).to include("active_role" => "worker", "available_roles" => %w[customer worker])
        end
      end

      response "401", "not logged in" do
        let(:Authorization) { nil }
        schema "$ref" => "#/components/schemas/error"
        run_test!
      end
    end

    patch "Update name, email or language" do
      tags "Me"
      security [ bearer: [] ]
      consumes "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }
      parameter name: :body, in: :body, schema: { type: :object, properties: { user: { type: :object, properties: { name: { type: :string }, email: { type: :string }, locale: { type: :string } } } } }
      let(:Authorization) { auth_headers_for(create(:user))["Authorization"] }

      response "200", "updated" do
        let(:body) { { user: { name: "Gurpreet", locale: "pa" } } }
        run_test! { expect(json.dig("data", "user")).to include("name" => "Gurpreet", "locale" => "pa") }
      end

      response "422", "invalid" do
        let(:body) { { user: { locale: "fr" } } }
        schema "$ref" => "#/components/schemas/error"
        run_test! { expect(json.dig("error", "details", "field_errors")).to have_key("locale") }
      end
    end
  end
end
