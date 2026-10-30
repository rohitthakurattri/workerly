module Api
  module V1
    module Worker
      class AvailabilitiesController < BaseController
        # PATCH /api/v1/worker/availability { available: true|false }
        def update
          authorize current_profile, :set_availability?
          current_profile.update!(available: ActiveModel::Type::Boolean.new.cast(params.require(:available)))
          render_profile
        end
      end
    end
  end
end
