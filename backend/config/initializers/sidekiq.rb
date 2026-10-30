# Separate logical Redis DBs: 0 = Sidekiq, 1 = cache, 2 = Action Cable.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6380")

Sidekiq.configure_server { |c| c.redis = { url: "#{redis_url}/0" } }
Sidekiq.configure_client { |c| c.redis = { url: "#{redis_url}/0" } }
