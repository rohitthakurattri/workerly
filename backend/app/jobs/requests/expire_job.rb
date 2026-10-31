module Requests
  # Every 5 minutes (config/schedule.yml): open/quoting requests past expires_at become expired.
  # Booked requests are out of scope (their status is no longer quotable). Open quotes expire
  # with their request, and quotes past their own valid_until are swept too.
  class ExpireJob < ApplicationJob
    queue_as :default

    def perform(now: Time.current)
      ServiceRequest.where(status: ServiceRequest::QUOTABLE_STATUSES).where(expires_at: ..now).find_each do |request|
        expired = ServiceRequest.transaction do
          request.lock!
          next false unless request.cancellable? && request.expires_at <= now

          request.update!(status: "expired")
          Quotations::CloseForRequest.call(request, now:)
        end
        Matching::CloseLeads.call(request) if expired
      end
      Quotation.where(status: "submitted").where(valid_until: ..now).update_all(status: "expired", updated_at: now)
    end
  end
end
