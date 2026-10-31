module Api
  module V1
    class NotificationsController < BaseController
      # GET /api/v1/notifications?cursor=… (newest first; meta.unread)
      def index
        records, meta = paginate(current_user.notifications, order: { id: :desc })
        render_data(records.map { |n| NotificationResource.new(n).to_h }, meta: meta.merge(unread: current_user.notifications.unread.count))
      end

      # POST /api/v1/notifications/:id/read
      def read
        current_user.notifications.find_by!(public_id: params[:id]).update!(read_at: Time.current)
        head :no_content
      end

      # POST /api/v1/notifications/read_all
      def read_all
        current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
        head :no_content
      end
    end
  end
end
