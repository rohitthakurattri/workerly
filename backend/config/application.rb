require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Workerly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Refresh tokens travel in an HttpOnly cookie, so cookies are needed in API mode.
    config.middleware.use ActionDispatch::Cookies

    config.active_job.queue_adapter = :sidekiq

    # Action Cable at /cable, only from the Workerly apps.
    config.action_cable.mount_path = "/cable"
    config.action_cable.allowed_request_origins = ENV.fetch("APP_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

    # Private media is only ever handed out as service URLs that expire quickly.
    config.active_storage.service_urls_expire_in = 5.minutes
    # Production serves files straight from S3 signed URLs; the Rails blob routes
    # (which never expire) are only needed for the local Disk service.
    config.active_storage.draw_routes = !Rails.env.production?
    config.time_zone = "UTC"
    config.i18n.available_locales = %i[en hi pa]
    config.i18n.default_locale = :en
    # Hindi/Punjabi text that isn't translated yet falls back to English instead of "translation missing".
    config.i18n.fallbacks = [ :en ]

    config.generators do |g|
      g.test_framework :rspec
      g.factory_bot dir: "spec/factories"
      g.orm :active_record, primary_key_type: :bigint
    end
  end
end
