module Api
  module V1
    module Worker
      class VerificationsController < BaseController
        # GET /api/v1/worker/verification — status, what's missing, documents and the latest decision.
        def show
          authorize current_profile, :show?
          p = WorkerProfileResource.new(current_profile).to_h
          render_data(p.slice(*%w[verification_status editable suspended missing documents last_decision submitted_at approved_at]))
        end
      end
    end
  end
end
