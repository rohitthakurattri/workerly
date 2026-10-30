module Api
  module V1
    module Admin
      # Every admin endpoint needs a staff (OTP + TOTP) session. Policies then check the staff role.
      class BaseController < Api::V1::BaseController
        before_action do
          raise ApplicationError.forbidden(:staff_session_required) unless current_session.staff?
        end
        after_action :verify_authorized
      end
    end
  end
end
