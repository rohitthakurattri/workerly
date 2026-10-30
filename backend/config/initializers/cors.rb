# Only Workerly's own apps may call the API from a browser.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("APP_ORIGINS", "").split(",").map(&:strip).reject(&:empty?))
    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true,
      expose: %w[X-Request-Id]
  end
end
