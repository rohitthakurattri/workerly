module Requests
  # Every 5 minutes (config/schedule.yml): open/quoting requests past expires_at become expired.
  # Phase 5 keeps requests with an accepted quote out of this (they are booked by then).
  class ExpireJob < ApplicationJob
    queue_as :default

    def perform(now: Time.current)
      ServiceRequest.where(status: ServiceRequest::QUOTABLE_STATUSES).where(expires_at: ..now).find_each do |request|
        expired = ServiceRequest.transaction do
          request.lock!
          next false unless request.cancellable? && request.expires_at <= now

          request.update!(status: "expired")
        end
        Matching::CloseLeads.call(request) if expired
      end
    end
  end
end
