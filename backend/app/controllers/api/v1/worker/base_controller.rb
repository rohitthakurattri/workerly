module Api
  module V1
    module Worker
      class BaseController < Api::V1::BaseController
        before_action { require_role!(:worker) }

        private

        def current_profile
          @current_profile ||= current_user.worker_profile || raise(ApplicationError.new(:worker_not_registered, status: :not_found))
        end

        def render_profile(status: :ok)
          render_data(WorkerProfileResource.new(current_profile.reload).to_h, status:)
        end
      end
    end
  end
end
