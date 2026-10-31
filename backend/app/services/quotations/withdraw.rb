module Quotations
  module Withdraw
    module_function

    def call(quotation:)
      ServiceRequest.transaction do
        quotation.service_request.lock!
        quotation.lock!
        raise ApplicationError.new(:quotation_not_editable, status: :conflict, details: { status: quotation.status }) unless quotation.submitted?

        quotation.update!(status: "withdrawn", withdrawn_at: Time.current)
      end
      Events.quote_changed(quotation, "quote.withdrawn")
      quotation
    end
  end
end
