module Api
  module V1
    module Auth
      class OtpVerificationsController < BaseController
        # POST /api/v1/auth/otp/verify
        # Consumers get a session straight away; staff get an MFA token for POST /auth/totp.
        def create
          scope = requested_scope
          user = Identity::VerifyOtp.call(phone: params.require(:phone), code: params.require(:code), scope:)

          if scope == "staff"
            render_data({ mfa_required: true, mfa_token: Identity::Tokens.mfa_token(user:),
                          expires_in: Identity::Tokens::MFA_TTL.to_i })
          else
            render_issued(Identity::Sessions.start(user:, scope:, role: params[:role],
                                                   ip: request.remote_ip, user_agent: request.user_agent),
                          status: :created)
          end
        end
      end
    end
  end
end
