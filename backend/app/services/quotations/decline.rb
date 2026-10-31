module Quotations
  # The customer says no to one quote; the others stay open.
  module Decline
    module_function

    def call(quotation:, reason: nil)
      ServiceRequest.transaction do
        quotation.service_request.lock!
        quotation.lock!
        raise ApplicationError.new(:quotation_not_acceptable, status: :conflict, details: { status: quotation.status }) unless quotation.submitted?

        quotation.update!(status: "declined", declined_at: Time.current, decline_reason: reason.to_s.strip.presence&.first(300))
      end
      Events.quote_changed(quotation, "quote.declined")
      QuotationDecidedJob.perform_later(quotation.id)
      quotation
    end
  end
end
