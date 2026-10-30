# Typed domain error rendered by Api::V1::BaseController as
# { error: { code, message, details, request_id } }.
class ApplicationError < StandardError
  attr_reader :code, :status, :details

  def initialize(code, message = nil, status: :unprocessable_content, details: {})
    @code = code.to_s
    @status = status
    @details = details
    super(message || I18n.t("errors.#{code}", default: code.to_s.humanize))
  end

  def self.unauthorized(code = :unauthorized, message = nil) = new(code, message, status: :unauthorized)
  def self.forbidden(code = :forbidden, message = nil) = new(code, message, status: :forbidden)
  def self.too_many_requests(code, message = nil, details: {}) = new(code, message, status: :too_many_requests, details:)
end
