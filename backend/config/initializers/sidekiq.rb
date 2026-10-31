# Separate logical Redis DBs: 0 = Sidekiq, 1 = cache, 2 = Action Cable.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6380")

Sidekiq.configure_server do |c|
  c.redis = { url: "#{redis_url}/0" }
  c.on(:startup) do
    schedule = Rails.root.join("config/schedule.yml")
    Sidekiq::Cron::Job.load_from_hash!(YAML.safe_load_file(schedule), source: "schedule") if schedule.exist?
  end
end
Sidekiq.configure_client { |c| c.redis = { url: "#{redis_url}/0" } }
