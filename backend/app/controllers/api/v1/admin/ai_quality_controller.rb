module Api
  module V1
    module Admin
      class AiQualityController < BaseController
        # GET /api/v1/admin/ai/quality?from=…&to=… (default: last 30 days)
        def show
          authorize :"admin/ai_quality", :show?
          to = parse_time(params[:to]) || Time.current
          from = parse_time(params[:from]) || (to - 30.days)
          render_data(Ai::TriageAccuracy.call(from:, to:))
        end

        private

        def parse_time(value)
          value.present? ? Time.zone.iso8601(value.to_s) : nil
        rescue ArgumentError
          raise ApplicationError.new(:validation_failed, details: { field_errors: { "time" => [ "is not a valid ISO 8601 time" ] } })
        end
      end
    end
  end
end
