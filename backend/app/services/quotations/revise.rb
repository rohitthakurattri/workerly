module Quotations
  # A worker changes their quote before it is accepted: a new immutable revision, version + 1.
  # The customer accepts a specific version, so a change made while they look at the old one
  # makes their accept fail with quotation_changed instead of booking a price they never saw.
  module Revise
    module_function

    def call(quotation:, params:, actor:)
      request = quotation.service_request
      ServiceRequest.transaction do
        request.lock!
        quotation.lock!
        raise ApplicationError.new(:quotation_not_editable, status: :conflict, details: { status: quotation.status }) unless quotation.submitted?
        raise ApplicationError.new(:request_closed, status: :conflict, details: { status: request.status }) unless request.quotable?
        raise ApplicationError.new(:too_many_revisions, status: :conflict, details: { max: Quotation::MAX_REVISIONS }) if quotation.current_version >= Quotation::MAX_REVISIONS

        version = quotation.current_version + 1
        draft = Build.call(params: params.reverse_merge(kind: quotation.kind), request:, actor:, version:)
        SaveRevision.call(quotation, draft)
        valid_until = params.key?(:valid_until) ? Create.valid_until(params, request) : quotation.valid_until
        quotation.update!(kind: draft.kind, current_version: version, valid_until:)
      end
      Events.quote_changed(quotation, "quote.updated")
      quotation
    end
  end
end
