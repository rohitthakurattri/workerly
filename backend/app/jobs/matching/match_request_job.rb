module Matching
  # Enqueued when a request is submitted (critical queue: the exit gate is "the right workers within 30 s").
  class MatchRequestJob < ApplicationJob
    queue_as :critical

    def perform(request_id)
      InviteWorkers.call(ServiceRequest.find(request_id))
    end
  end
end
