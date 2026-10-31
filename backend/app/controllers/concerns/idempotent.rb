# `idempotent :accept` makes an action require an Idempotency-Key header. The first successful
# response is stored per user and key for 24 h; a replay with the same request gets it back
# (Idempotent-Replayed: true) without running the action again. Failed attempts are not stored,
# so the client can retry with the same key.
module Idempotent
  extend ActiveSupport::Concern

  class_methods do
    def idempotent(*actions) = around_action(:with_idempotency_key, only: actions)
  end

  private

  def with_idempotency_key
    key = request.headers["Idempotency-Key"].to_s.strip
    raise ApplicationError.new(:idempotency_key_required, status: :bad_request) if key.empty?
    raise ApplicationError.new(:idempotency_key_invalid, status: :bad_request) unless key.match?(/\A[\w.:-]{8,255}\z/)

    fingerprint = Digest::SHA256.hexdigest([ request.method, request.path, request.raw_post ].join("\n"))
    record = claim_idempotency_key(key, fingerprint)
    return replay(record) if record.completed?

    begin
      yield
    rescue StandardError
      record.delete
      raise
    end
    if response.status < 300
      record.update!(response_status: response.status, response_body: JSON.parse(response.body.presence || "null"), completed_at: Time.current)
    else
      record.delete
    end
  end

  def claim_idempotency_key(key, fingerprint)
    IdempotencyKey.create!(user: current_user, key:, request_fingerprint: fingerprint)
  rescue ActiveRecord::RecordNotUnique
    existing = IdempotencyKey.find_by!(user: current_user, key:)
    raise ApplicationError.new(:idempotency_key_reused, status: :unprocessable_content) if existing.request_fingerprint != fingerprint
    raise ApplicationError.new(:idempotency_key_in_progress, status: :conflict) unless existing.completed?

    existing
  end

  def replay(record)
    response.set_header("Idempotent-Replayed", "true")
    render json: record.response_body, status: record.response_status
  end
end
