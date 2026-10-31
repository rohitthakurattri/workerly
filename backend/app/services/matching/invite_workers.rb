module Matching
  # Picks the best-ranked eligible workers for an open request and invites them, once.
  # Safe to run twice (row lock + matched_at + the unique index on invitations).
  module InviteWorkers
    module_function

    def call(request)
      invitations = ServiceRequest.transaction do
        request.lock!
        next nil unless request.open? && request.matched_at.nil?

        now = Time.current
        ranked = Rank.order(FindCandidates.call(request, now:)).first(Workerly.config.match_fanout)
        rows = ranked.each_with_index.map do |(c, score), i|
          { public_id: SecureRandom.uuid_v7, service_request_id: request.id, worker_profile_id: c.worker_profile_id,
            rank: i + 1, rank_score: score, distance_m: c.distance_m, created_at: now, updated_at: now }
        end
        RequestInvitation.insert_all!(rows) if rows.any?
        request.update!(matched_at: now, invited_count: rows.size)
        request.invitations.to_a
      end
      return [] if invitations.nil?

      invitations.each { |inv| NotifyWorkerJob.perform_later(inv.id) }
      CustomerMatchedJob.perform_later(request.id)
      invitations
    end
  end
end
