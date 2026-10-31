module Quotations
  # Tells a worker their quote was not chosen (declined, or another quote was accepted). In-app and push only.
  class QuotationDecidedJob < ApplicationJob
    queue_as :default

    def perform(quotation_id)
      q = Quotation.includes(worker_profile: :user, service_request: :service_category).find(quotation_id)
      return unless q.declined?

      user = q.worker_profile.user
      request = q.service_request
      key = q.decline_reason == "another_accepted" ? "quote_lost" : "quote_declined"
      Notifications::Deliver.call(
        user:, app: "worker", kind: "quote.#{key.delete_prefix('quote_')}",
        title: I18n.t("notifications.#{key}.title", category: request.service_category.name(user.locale), locale: user.locale),
        url: "/quotes", data: { quotation_id: q.public_id }
      )
    end
  end
end
