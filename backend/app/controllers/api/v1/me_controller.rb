module Api
  module V1
    class MeController < BaseController
      # GET /api/v1/me
      def show
        authorize current_user, :show?
        render_data(me_payload)
      end

      # PATCH /api/v1/me
      def update
        authorize current_user, :update?
        current_user.update!(params.require(:user).permit(:name, :email, :locale))
        render_data(me_payload)
      end

      private

      def me_payload
        { user: UserResource.new(current_user).to_h, active_role: current_role,
          available_roles: current_user.roles_for_scope(current_session.scope),
          session: { scope: current_session.scope, expires_at: current_session.expires_at.iso8601 } }
      end
    end
  end
end
