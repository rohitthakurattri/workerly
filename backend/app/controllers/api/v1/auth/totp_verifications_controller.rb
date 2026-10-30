module Api
  module V1
    module Auth
      class TotpVerificationsController < BaseController
        # POST /api/v1/auth/totp — second step of staff login.
        def create
          claims = Identity::Tokens.decode(params.require(:mfa_token), typ: "mfa")
          user = User.kept.find_by(public_id: claims["sub"])
          raise ApplicationError.unauthorized(:invalid_token) unless user&.staff?
          raise ApplicationError.forbidden(:account_suspended) unless user.active?

          Identity::Totp.verify!(user, params.require(:code))
          render_issued(Identity::Sessions.start(user:, scope: "staff", role: params[:role], mfa: true,
                                                 ip: request.remote_ip, user_agent: request.user_agent),
                        status: :created)
        end
      end
    end
  end
end
