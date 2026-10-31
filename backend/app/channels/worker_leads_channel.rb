# New and closed leads for one worker, live. Same gate as the leads API: approved, not suspended.
class WorkerLeadsChannel < ApplicationCable::Channel
  def subscribed
    profile = current_user.worker_profile
    return reject unless current_role == "worker" && profile&.can_receive_leads?

    stream_for profile
  end
end
