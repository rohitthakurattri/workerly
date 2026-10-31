module Matching
  # Tells invited workers' open apps that a lead is gone (cancelled, expired or booked).
  module CloseLeads
    module_function

    def call(request)
      request.invitations.includes(:worker_profile).find_each do |inv|
        WorkerLeadsChannel.broadcast_to(inv.worker_profile, { type: "lead.closed", id: request.public_id, status: request.status })
      end
    end
  end
end
