module Bookings
  # The booking state machine: which role may fire which event from which status, and where it
  # leads. Everything else (timestamps, revisions, approvals) lives in Bookings::Perform.
  module Transitions
    module_function

    SCHEDULE = ->(b) { b.confirmed? ? (b.kind == "inspection" ? "inspection_scheduled" : "scheduled") : b.status }

    RULES = {
      schedule: { roles: %w[worker], from: { "confirmed" => SCHEDULE, "inspection_scheduled" => SCHEDULE, "scheduled" => SCHEDULE } },
      check_in: { roles: %w[worker], from: { "inspection_scheduled" => "inspecting" } },
      final_quotation: { roles: %w[worker], from: { "inspecting" => "awaiting_final_approval" } },
      approve_final: { roles: %w[customer], from: { "awaiting_final_approval" => "scheduled" } },
      reject_final: { roles: %w[customer], from: { "awaiting_final_approval" => "closed_after_inspection" } },
      start: { roles: %w[worker], from: { "scheduled" => "in_progress" } },
      change_order: { roles: %w[worker], from: { "in_progress" => "awaiting_change_approval" } },
      approve_change: { roles: %w[customer], from: { "awaiting_change_approval" => "in_progress" } },
      reject_change: { roles: %w[customer], from: { "awaiting_change_approval" => "in_progress" } },
      complete: { roles: %w[worker], from: { "in_progress" => "completed" } },
      cancel: { roles: %w[customer worker], from: Booking::BEFORE_WORK_STATUSES.index_with("cancelled") },
      admin_cancel: { roles: %w[admin support],
                      from: %w[confirmed inspection_scheduled inspecting awaiting_final_approval scheduled in_progress
                               awaiting_change_approval].index_with("cancelled") },
      dispute: { roles: %w[customer], from: { "completed" => "disputed", "paid" => "disputed" } },
      resolve_dispute: { roles: %w[admin support], from: { "disputed" => ->(b) { b.status_before_dispute || "completed" } } }
    }.freeze

    EVENTS = RULES.keys.freeze

    # The status the event leads to, or an error explaining why it can't happen now.
    def target!(booking, event, role)
      rule = RULES.fetch(event)
      raise ApplicationError.forbidden(:role_required, I18n.t("errors.role_required", roles: rule[:roles].join(", "))) unless rule[:roles].include?(role)

      to = rule[:from][booking.status]
      unless to
        raise ApplicationError.new(:invalid_transition, status: :conflict, details: { from: booking.status, event: event.to_s })
      end
      to.respond_to?(:call) ? to.call(booking) : to
    end

    # Events this role could fire right now (the apps show only these buttons).
    def available(booking, role)
      RULES.select { |_, r| r[:roles].include?(role) && r[:from].key?(booking.status) }.keys.map(&:to_s)
    end
  end
end
