module Requests
  # draft -> open. Copies the address so later edits to the address book never move a live request.
  # Matching runs in a job once the transaction has committed.
  module Submit
    module_function

    def call(request:)
      ServiceRequest.transaction do
        request.lock!
        unless request.draft?
          raise ApplicationError.new(:invalid_transition, status: :conflict, details: { from: request.status, to: "open" })
        end

        missing = request.missing
        raise ApplicationError.new(:request_incomplete, details: { missing: }) if missing.any?

        active = request.customer.service_requests.active.count
        raise ApplicationError.new(:too_many_active_requests, details: { max: ServiceRequest::MAX_ACTIVE }) if active >= ServiceRequest::MAX_ACTIVE

        address = request.address
        now = Time.current
        request.update!(status: "open", submitted_at: now, expires_at: now + Workerly.config.request_ttl_hours.hours,
                        city: address.city, location: address.location, address_snapshot: address.snapshot)
      end
      Matching::MatchRequestJob.perform_later(request.id)
      request
    end
  end
end
