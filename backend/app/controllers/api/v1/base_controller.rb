module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      include ActiveStorage::SetCurrent # host for expiring Disk-service URLs in development

      before_action :set_request_context
      before_action :authenticate!
      after_action :no_store

      rescue_from StandardError, with: :render_internal_error unless Rails.env.local?
      rescue_from ApplicationError, with: :render_application_error
      rescue_from ActiveRecord::RecordNotFound, with: -> { render_error(:not_found, :not_found) }
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActionController::ParameterMissing, with: ->(e) { render_error(:bad_request, :parameter_missing, details: { param: e.param }) }
      rescue_from Pundit::NotAuthorizedError, with: ->(e) { render_error(:forbidden, e.policy.try(:denial_reason) || :forbidden) }

      attr_reader :current_auth

      def current_user = current_auth&.user
      def current_session = current_auth&.session
      def current_role = current_auth&.role
      # Pundit policies receive the user plus the active role, never just the user.
      def pundit_user = current_auth

      private

      def authenticate!
        @current_auth = Identity::Authenticate.call(bearer_token)
        Current.auth = @current_auth
      end

      def set_request_context
        Current.request_id = request.request_id
        Current.ip = request.remote_ip
        Current.user_agent = request.user_agent
      end

      def require_role!(*roles)
        return if roles.map(&:to_s).include?(current_role)

        raise ApplicationError.forbidden(:role_required, I18n.t("errors.role_required", roles: roles.join(", ")))
      end

      def paginate(scope, order:)
        page = Shared::Pagination.call(scope, order:, cursor: params[:cursor], limit: params[:limit])
        [ page.records, { next_cursor: page.next_cursor } ]
      end

      def bearer_token
        request.authorization.to_s[/\ABearer (.+)\z/, 1]
      end

      def render_data(data, status: :ok, meta: nil)
        render json: { data:, meta: }.compact, status:
      end

      def render_error(status, code, message: nil, details: {})
        message ||= I18n.t("errors.#{code}", default: code.to_s.humanize)
        render json: { error: { code: code.to_s, message:, details:, request_id: request.request_id } }, status:
      end

      def render_application_error(error)
        response.set_header("Retry-After", error.details[:retry_after].to_s) if error.details[:retry_after]
        render_error(error.status, error.code, message: error.message, details: error.details)
      end

      def render_record_invalid(error)
        render_error(:unprocessable_content, :validation_failed,
                     details: { field_errors: error.record.errors.to_hash(true) })
      end

      def render_internal_error(error)
        Rails.error.report(error, handled: true)
        render_error(:internal_server_error, :internal_error)
      end

      # Authenticated API responses must never land in a shared-device PWA or proxy cache.
      def no_store
        response.headers["Cache-Control"] = "no-store"
      end
    end
  end
end
