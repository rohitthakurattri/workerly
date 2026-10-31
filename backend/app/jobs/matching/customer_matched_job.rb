module Matching
  # Tells the customer how many workers got their request (or that none are free yet).
  class CustomerMatchedJob < ApplicationJob
    queue_as :default

    def perform(request_id)
      request = ServiceRequest.includes(:customer).find(request_id)
      user = request.customer
      key = request.invited_count.positive? ? "request_matched" : "request_unmatched"
      Notifications::Deliver.call(
        user:, app: "customer", kind: "request.#{key.delete_prefix('request_')}",
        title: I18n.t("notifications.#{key}.title", count: request.invited_count, locale: user.locale),
        url: "/requests/#{request.public_id}", data: { request_id: request.public_id, invited: request.invited_count }
      )
    end
  end
end
