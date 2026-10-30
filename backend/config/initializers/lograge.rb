Rails.application.configure do
  config.lograge.enabled = !Rails.env.development?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_payload do |controller|
    { request_id: controller.request.request_id, user_id: controller.try(:current_user)&.id }
  end
end
