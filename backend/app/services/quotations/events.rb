module Quotations
  # Live updates after commit. The customer's open request page refetches its quotes on any
  # request-channel event, so payloads carry ids only.
  module Events
    module_function

    def quote_changed(quotation, type)
      request = quotation.service_request
      RequestChannel.broadcast_to(request, { type:, id: quotation.public_id })
      case type
      when "quote.new", "quote.updated" then CustomerQuotedJob.perform_later(quotation.id, type)
      when "quote.declined" then worker_status(quotation)
      end
    end

    def worker_status(quotation)
      WorkerLeadsChannel.broadcast_to(quotation.worker_profile, {
        type: "quote.status", lead_id: quotation.service_request.public_id, id: quotation.public_id, status: quotation.status
      })
    end
  end
end
