module Api
  module V1
    module Auth
      class OtpRequestsController < BaseController
        # POST /api/v1/auth/otp
        # The response is the same whether or not the phone has an account.
        def create
          result = Identity::RequestOtp.call(phone: params.require(:phone), ip: request.remote_ip,
                                             user_agent: request.user_agent)
          render_data(result.to_h, status: :accepted)
        end
      end
    end
  end
end
