module Api
  module V1
    module Auth
      class TokensController < BaseController
        before_action :verify_origin!

        # POST /api/v1/auth/refresh  { scope?, role?, refresh_token? }
        def create
          scope = requested_scope
          raw = body_delivery? ? params.require(:refresh_token) : cookies[COOKIE_NAMES.fetch(scope)]
          render_issued(Identity::Sessions.refresh(raw_token: raw, role: params[:role]))
        rescue ApplicationError => e
          clear_refresh_cookie(scope) if e.status == :unauthorized && scope
          raise
        end
      end
    end
  end
end
