module Quotations
  # A request stopped taking quotes (cancelled or expired): its open quotes expire with it.
  # Call inside the transaction that changes the request.
  module CloseForRequest
    module_function

    def call(request, now: Time.current)
      request.quotations.where(status: "submitted").update_all(status: "expired", updated_at: now)
    end
  end
end
