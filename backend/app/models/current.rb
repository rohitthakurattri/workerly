# Per-request context, set by Api::V1::BaseController and read by the audit log.
class Current < ActiveSupport::CurrentAttributes
  attribute :auth, :request_id, :ip, :user_agent
end
