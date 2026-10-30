module Api
  module V1
    module Auth
      class SessionsController < BaseController
        before_action :authenticate!

        # DELETE /api/v1/auth/session — revokes this login's whole token family.
        def destroy
          current_session.revoke!("logout")
          clear_refresh_cookie(current_session.scope)
          head :no_content
        end
      end
    end
  end
end
