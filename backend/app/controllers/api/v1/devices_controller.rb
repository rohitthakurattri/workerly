module Api
  module V1
    # Web push subscriptions for the signed-in user (customer or worker app).
    class DevicesController < BaseController
      # GET /api/v1/devices/push_config -> { enabled, public_key }
      def push_config
        render_data({ enabled: Notifications::Push.enabled?, public_key: Workerly.config.vapid_public_key })
      end

      # POST /api/v1/devices { endpoint, keys: { p256dh, auth } }
      # The same browser endpoint moves to whoever is signed in now (shared phones).
      def create
        app = { "customer" => "customer", "worker" => "worker" }[current_role]
        raise ApplicationError.forbidden(:consumer_session_required) unless app

        p = params.permit(:endpoint, keys: %i[p256dh auth])
        device = DeviceSubscription.find_or_initialize_by(endpoint: p.require(:endpoint))
        device.update!(user: current_user, app:, p256dh: p.dig(:keys, :p256dh), auth: p.dig(:keys, :auth),
                       user_agent: request.user_agent.to_s.first(255), last_seen_at: Time.current, failed_at: nil)
        render_data({ id: device.public_id, app: device.app }, status: :created)
      end

      # DELETE /api/v1/devices { endpoint } — on logout or when the user turns alerts off.
      def destroy
        current_user.device_subscriptions.where(endpoint: params.require(:endpoint)).destroy_all
        head :no_content
      end
    end
  end
end
