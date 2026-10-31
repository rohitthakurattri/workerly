module Api
  module V1
    class CableTicketsController < BaseController
      # POST /api/v1/cable_tickets -> { ticket, url, expires_in }. Valid once, for 60 s.
      def create
        render_data({ ticket: Identity::Tokens.cable_ticket(session: current_session, role: current_role),
                      url: ENV.fetch("ACTION_CABLE_URL", "ws://localhost:3000/cable"),
                      expires_in: Identity::Tokens::CABLE_TTL.to_i }, status: :created)
      end
    end
  end
end
