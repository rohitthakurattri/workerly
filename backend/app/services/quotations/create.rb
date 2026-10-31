module Quotations
  # An invited worker's first quote on a lead. The request row lock serialises this against
  # other quotes (the limit), revisions and the customer's accept.
  module Create
    module_function

    def call(invitation:, params:, actor:)
      request = invitation.service_request
      quotation = ServiceRequest.transaction do
        request.lock!
        raise ApplicationError.new(:request_closed, status: :conflict, details: { status: request.status }) unless request.quotable?
        raise ApplicationError.new(:lead_declined, status: :conflict) if invitation.reload.declined?
        if request.customer_id == invitation.worker_profile.user_id
          raise ApplicationError.forbidden(:own_request) # matching never invites them; belt and braces
        end
        raise ApplicationError.new(:already_quoted, status: :conflict) if invitation.quotation

        limit = Workerly.config.max_quotes_per_request
        if request.quotations.live.count >= limit
          raise ApplicationError.new(:quote_limit_reached, status: :conflict, details: { max: limit })
        end

        draft = Build.call(params:, request:, actor:, version: 1)
        q = Quotation.create!(service_request: request, worker_profile: invitation.worker_profile, invitation:,
                              kind: draft.kind, current_version: 1, valid_until: valid_until(params, request))
        SaveRevision.call(q, draft)
        request.update!(status: "quoting") if request.open?
        q
      end
      Events.quote_changed(quotation, "quote.new")
      quotation
    rescue ActiveRecord::RecordNotUnique
      raise ApplicationError.new(:already_quoted, status: :conflict)
    end

    # Optional, never past the request's own expiry.
    def valid_until(params, request)
      return request.expires_at if params[:valid_until].blank?

      time = Time.zone.parse(params[:valid_until].to_s)
      unless time && time > 1.hour.from_now && time <= request.expires_at
        raise ApplicationError.new(:validation_failed, details: { field_errors: { "valid_until" => [ "must be between an hour from now and the request's expiry" ] } })
      end
      time
    rescue ArgumentError
      raise ApplicationError.new(:validation_failed, details: { field_errors: { "valid_until" => [ "is not a valid time" ] } })
    end
  end
end
