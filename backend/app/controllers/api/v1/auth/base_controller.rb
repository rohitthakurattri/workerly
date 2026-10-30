module Api
  module V1
    module Auth
      # Shared refresh-token cookie handling. Consumer (customer + worker) and staff
      # sessions use separate cookies so an admin login never replaces a customer one.
      class BaseController < Api::V1::BaseController
        include ActionController::Cookies

        skip_before_action :authenticate!

        COOKIE_NAMES = { "consumer" => "wk_rt", "staff" => "wk_rt_staff" }.freeze
        COOKIE_PATH = "/api/v1/auth"

        private

        def requested_scope
          scope = params.fetch(:scope, "consumer").to_s
          raise ApplicationError.new(:invalid_scope, status: :bad_request) unless UserSession::SCOPES.include?(scope)

          scope
        end

        # Native apps ask for the refresh token in the body; browsers get an HttpOnly cookie.
        def body_delivery? = params[:token_delivery] == "body"

        def render_issued(issued, status: :ok)
          if issued.refresh_token && !body_delivery?
            cookies[COOKIE_NAMES.fetch(issued.session.scope)] = {
              value: issued.refresh_token, httponly: true, secure: Workerly.config.secure_cookies,
              same_site: :lax, path: COOKIE_PATH, expires: issued.session.expires_at
            }
          end
          render_data(session_payload(issued), status:)
        end

        def session_payload(issued)
          {
            access_token: issued.access_token,
            token_type: "Bearer",
            expires_in: Identity::Tokens::ACCESS_TTL.to_i,
            refresh_token: (issued.refresh_token if body_delivery?),
            session: { scope: issued.session.scope, expires_at: issued.session.expires_at.iso8601 },
            active_role: issued.role,
            user: UserResource.new(issued.session.user).to_h
          }.compact
        end

        def clear_refresh_cookie(scope)
          cookies.delete(COOKIE_NAMES.fetch(scope), path: COOKIE_PATH)
        end

        # Cookie-authenticated calls must come from one of our own origins (CSRF guard on top of SameSite=Lax).
        def verify_origin!
          return if body_delivery?

          allowed = ENV.fetch("APP_ORIGINS", "").split(",").map(&:strip)
          raise ApplicationError.forbidden(:origin_not_allowed) unless allowed.include?(request.origin)
        end
      end
    end
  end
end
