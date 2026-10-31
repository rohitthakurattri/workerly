module Quotations
  # "New quote: ₹1,999" (or "Quote updated") to the customer: in-app and push, no SMS.
  class CustomerQuotedJob < ApplicationJob
    queue_as :default

    def perform(quotation_id, type)
      q = Quotation.includes(:worker_profile, service_request: %i[customer service_category]).find(quotation_id)
      return unless q.submitted?

      request = q.service_request
      user = request.customer
      revision = q.current_revision
      key = type == "quote.new" ? "quote_new" : "quote_revised"
      Notifications::Deliver.call(
        user:, app: "customer", kind: type,
        title: I18n.t("notifications.#{key}.title", amount: Shared::Money.format(revision.total_minor, revision.currency_code), locale: user.locale),
        body: I18n.t("notifications.#{key}.body", worker: q.worker_profile.user.name, category: request.service_category.name(user.locale), locale: user.locale),
        url: "/requests/#{request.public_id}", data: { request_id: request.public_id, quotation_id: q.public_id }
      )
    end
  end
end
