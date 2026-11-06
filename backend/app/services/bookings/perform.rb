module Bookings
  # Runs one booking event in one transaction: checks the role and status (Transitions), applies
  # the event, recomputes what the customer owes (AmountDue), writes the history row, and updates
  # the request. Notifications and live updates go out after commit (Events).
  #
  # Lock order matches Quotations::Accept: request, then booking, then quotation.
  module Perform
    module_function

    MAX_SCHEDULE_AHEAD = 30.days

    # A block runs inside the same transaction (disputes use it to write their own row).
    def call(booking:, event:, actor:, role:, params: {}, ip: nil, user_agent: nil, now: Time.current, &inside)
      event = event.to_sym
      from = nil
      reopened = false
      Booking.transaction do
        booking.service_request.lock!
        booking.lock!
        from = booking.status
        to = Transitions.target!(booking, event, role)
        metadata = send(:"apply_#{event}", booking, params.to_h.with_indifferent_access, actor:, role:, now:, ip:, user_agent:) || {}

        booking.status = to
        booking.approved_total_minor = AmountDue.call(booking)
        booking.save!
        BookingStatusHistory.create!(booking:, from_status: from, to_status: to, actor:, actor_role: role,
                                     metadata: metadata.merge(event: event.to_s))
        reopened = after_status_change(booking, now)
        inside&.call(booking)
      end
      # Runs now, or after the caller's transaction commits (payments mark bookings paid inside theirs).
      ActiveRecord.after_all_transactions_commit { Events.changed(booking, event, from:, role:, reopened:) }
      booking
    end

    # -- events --------------------------------------------------------------------------------

    def apply_schedule(booking, params, now:, **)
      time = parse_time(params[:scheduled_at])
      unless time && time > now && time <= now + MAX_SCHEDULE_AHEAD
        raise ApplicationError.new(:validation_failed, details: { field_errors: { "scheduled_at" => [ "must be in the next 30 days" ] } })
      end
      booking.scheduled_at = time
      { scheduled_at: time.iso8601 }
    end

    def apply_check_in(booking, _params, now:, **)
      booking.checked_in_at = now
      nil
    end

    def apply_final_quotation(booking, params, actor:, **) = send_revision(booking, params, actor:, stage: "final")
    def apply_change_order(booking, params, actor:, **) = send_revision(booking, params, actor:, stage: "change_order")

    def apply_approve_final(booking, params, actor:, ip:, user_agent:, **) = decide(booking, params, "approved", actor:, ip:, user_agent:)
    def apply_reject_final(booking, params, actor:, ip:, user_agent:, **) = decide(booking, params, "rejected", actor:, ip:, user_agent:)
    def apply_approve_change(booking, params, actor:, ip:, user_agent:, **) = decide(booking, params, "approved", actor:, ip:, user_agent:)
    def apply_reject_change(booking, params, actor:, ip:, user_agent:, **) = decide(booking, params, "rejected", actor:, ip:, user_agent:)

    def apply_start(booking, _params, now:, **)
      booking.started_at = now
      booking.checked_in_at ||= now # fixed-price jobs check in by starting
      nil
    end

    def apply_complete(booking, _params, now:, **)
      booking.completed_at = now
      nil
    end

    def apply_cancel(booking, params, role:, now:, **)
      booking.cancelled_at = now
      booking.cancelled_by = role
      booking.cancel_reason = params[:reason].to_s.strip.presence&.first(500)
      { reason: booking.cancel_reason }.compact
    end

    def apply_admin_cancel(booking, params, now:, **)
      reason = params[:reason].to_s.strip
      raise ApplicationError.new(:reason_required) if reason.empty?

      booking.cancelled_at = now
      booking.cancelled_by = "admin"
      booking.cancel_reason = reason.first(500)
      ::Admin::Audit.record!(action: "booking.cancelled", target: booking, reason: booking.cancel_reason,
                             changes: { status: [ booking.status, "cancelled" ] })
      { reason: booking.cancel_reason }
    end

    def apply_dispute(booking, _params, **)
      booking.status_before_dispute = booking.status
      nil
    end

    # Payment events (role "system"): fully paid, or fully refunded.
    def apply_pay(booking, _params, **)
      booking.status_before_dispute = "paid" if booking.disputed?
      { paid_minor: booking.paid_minor }
    end

    def apply_refund(booking, _params, **)
      booking.status_before_dispute = "refunded" if booking.disputed?
      nil
    end

    def apply_resolve_dispute(booking, _params, **)
      booking.status_before_dispute = nil
      nil
    end

    # -- helpers -------------------------------------------------------------------------------

    # The worker's final price after an inspection, or extra charges during the work: a new
    # immutable revision on the booking's quotation, waiting for the customer.
    def send_revision(booking, params, actor:, stage:)
      quotation = booking.quotation
      quotation.lock!
      if quotation.current_version >= Quotation::MAX_REVISIONS + 10
        raise ApplicationError.new(:too_many_revisions, status: :conflict)
      end

      draft = Quotations::Build.call(params: params.merge(kind: "fixed"), request: booking.service_request, actor:,
                                     version: quotation.current_version + 1, stage:)
      revision = Quotations::SaveRevision.call(quotation, draft)
      quotation.update!(current_version: revision.version)
      booking.pending_revision = revision
      { revision_id: revision.public_id, version: revision.version, total_minor: revision.total_minor }
    end

    # The customer approves or rejects exactly the revision that is waiting, once.
    def decide(booking, params, decision, actor:, ip:, user_agent:)
      pending = booking.pending_revision
      if pending.nil? || params[:revision_id].to_s != pending.public_id
        raise ApplicationError.new(:revision_not_pending, status: :conflict, details: { pending_revision_id: pending&.public_id })
      end

      BookingApproval.create!(booking:, quotation_revision: pending, decision:, decided_by: actor, ip:, user_agent:)
      booking.pending_revision = nil
      { revision_id: pending.public_id, version: pending.version, decision: }
    end

    # Request side effects. Returns true when the request reopened for the other quotes.
    def after_status_change(booking, now)
      request = booking.service_request
      if booking.completed? && !request.fulfilled?
        request.update!(status: "fulfilled")
      elsif (booking.cancelled? && booking.started_at.nil?) || booking.closed_after_inspection?
        return ReopenRequest.call(booking, now:)
      end
      false
    end

    def parse_time(value)
      value.present? ? Time.zone.iso8601(value.to_s) : nil
    rescue ArgumentError
      nil
    end
  end
end
