module Api
  module V1
    module Auth
      class RolesController < BaseController
        before_action :authenticate!

        # POST /api/v1/auth/switch_role { role } — new access token, same session.
        # Roles switch only within the session's scope (customer<->worker, or between staff roles).
        def create
          render_issued(Identity::Sessions.switch_role(session: current_session, role: params.require(:role)))
        end
      end
    end
  end
end
