module Api
  module V1
    module Worker
      class RegistrationsController < Api::V1::BaseController
        # POST /api/v1/worker/registration { name? }
        # A logged-in customer becomes a worker. Returns the draft profile and an access
        # token already switched to the worker role.
        def create
          raise ApplicationError.forbidden(:consumer_session_required) unless current_session.scope == "consumer"

          current_user.update!(name: params[:name]) if params[:name].present?
          profile = Workers::Register.call(user: current_user)
          issued = Identity::Sessions.switch_role(session: current_session, role: "worker")
          render_data({ profile: WorkerProfileResource.new(profile).to_h, access_token: issued.access_token,
                        expires_in: Identity::Tokens::ACCESS_TTL.to_i, active_role: "worker" }, status: :created)
        end
      end
    end
  end
end
