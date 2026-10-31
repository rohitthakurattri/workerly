module Disputes
  # Support closes a dispute with a written resolution; the booking returns to where it was.
  # Refunds are a finance action in Phase 7.
  module Resolve
    module_function

    def call(dispute:, auth:, resolution:, now: Time.current)
      resolution = resolution.to_s.strip
      raise ApplicationError.new(:reason_required) if resolution.empty?

      Bookings::Perform.call(booking: dispute.booking, event: :resolve_dispute, actor: auth.user, role: auth.role, now:) do
        dispute.lock!
        raise ApplicationError.new(:dispute_not_open, status: :conflict) unless dispute.open?

        dispute.update!(status: "resolved", resolution:, resolved_by: auth.user, resolved_at: now)
        ::Admin::Audit.record!(action: "dispute.resolved", target: dispute, reason: resolution, auth:)
      end
      dispute
    end
  end
end
