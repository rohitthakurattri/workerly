module Api
  module V1
    module Customer
      class TriagesController < BaseController
        # POST /api/v1/customer/service_requests/:service_request_id/triage
        # AI suggestion from the draft's text and photos. 503 ai_unavailable means "pick the category
        # yourself": the flag is off, the provider failed, or the circuit breaker is open.
        def create
          service_request = find_request
          authorize service_request, :update?
          suggestion = Ai::TriageRequest.call(request: service_request, user: current_user)
          render_data(TriageResource.new(suggestion).to_h)
        end
      end
    end
  end
end
