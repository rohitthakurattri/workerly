module Api
  module V1
    class CitiesController < BaseController
      skip_before_action :authenticate!

      # GET /api/v1/cities — cities where Workerly operates.
      def index
        render_data(City.launched.includes(:state).order(:slug).map { |c| CityResource.new(c).to_h })
      end

      private

      def no_store
        expires_in 5.minutes, public: true
      end
    end
  end
end
