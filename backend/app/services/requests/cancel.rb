module Requests
  module Cancel
    module_function

    def call(request:, reason: nil)
      ServiceRequest.transaction do
        request.lock!
        unless request.cancellable?
          raise ApplicationError.new(:request_not_cancellable, status: :conflict, details: { status: request.status })
        end

        request.update!(status: "cancelled", cancelled_at: Time.current, cancel_reason: reason.to_s.strip.presence)
      end
      Matching::CloseLeads.call(request)
      request
    end
  end
end
