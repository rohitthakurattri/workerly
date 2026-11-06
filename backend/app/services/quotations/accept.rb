module Quotations
  # The customer accepts one quotation, at the version they saw. Creates the booking, records
  # consent, declines every other quote and books the request, all in one transaction.
  #
  # Two accepts at once (two tabs, two quotes, a double tap) are serialised by the request row
  # lock; the partial unique indexes on bookings and quotations stop a second booking even if a
  # future code path forgets the lock.
  module Accept
    module_function

    def call(quotation:, version:, customer:, ip: nil, user_agent: nil, now: Time.current)
      attempts = 0
      begin
        booking = book(quotation, version, customer, ip, user_agent, now)
      rescue ActiveRecord::Deadlocked
        # Postgres rolled this attempt back so the other one could finish; run the checks again.
        retry if (attempts += 1) < 3
        raise
      end
      AcceptedJob.perform_later(booking.id)
      booking
    rescue ActiveRecord::RecordNotUnique
      raise ApplicationError.new(:request_already_booked, status: :conflict)
    end

    def book(quotation, version, customer, ip, user_agent, now)
      request = quotation.service_request
      ServiceRequest.transaction do
        request.lock!
        quotation.lock!
        quotation.revisions.reset
        check!(request, quotation, version, now)

        revision = quotation.current_revision
        rule = CommissionRule.for(city: request.city, category: request.service_category, at: now)
        booking = Booking.create!(
          commission_bps: rule&.percent_bps, commission_fixed_minor: rule&.fixed_minor,
          service_request: request, quotation:, customer:, worker_profile: quotation.worker_profile, kind: quotation.kind,
          status: "confirmed", approved_total_minor: revision.total_minor, currency_code: revision.currency_code,
          confirmed_at: now, address_revealed_at: now
        )
        BookingApproval.create!(booking:, quotation_revision: revision, decision: "approved", decided_by: customer, ip:, user_agent:)
        BookingStatusHistory.create!(booking:, from_status: nil, to_status: "confirmed", actor: customer, actor_role: "customer",
                                     metadata: { quotation_id: quotation.public_id, version: revision.version })
        quotation.update!(status: "accepted", accepted_at: now)
        request.quotations.where(status: "submitted").where.not(id: quotation.id)
               .update_all(status: "declined", declined_at: now, decline_reason: "another_accepted", updated_at: now)
        request.update!(status: "booked")
        booking
      end
    end

    def check!(request, quotation, version, now)
      if request.booked? || request.bookings.active.exists?
        raise ApplicationError.new(:request_already_booked, status: :conflict)
      end
      raise ApplicationError.new(:request_closed, status: :conflict, details: { status: request.status }) unless request.quotable?(now)
      unless quotation.submitted?
        raise ApplicationError.new(:quotation_not_acceptable, status: :conflict, details: { status: quotation.status })
      end
      raise ApplicationError.new(:quotation_expired, status: :conflict) if quotation.lapsed?(now)
      if version.to_i != quotation.current_version
        raise ApplicationError.new(:quotation_changed, status: :conflict, details: { current_version: quotation.current_version })
      end
      raise ApplicationError.new(:worker_unavailable, status: :conflict) unless quotation.worker_profile.can_receive_leads?
    end
  end
end
