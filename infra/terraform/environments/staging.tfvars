env            = "staging"
domain         = "staging.workerly.in"
hosted_zone_id = "Z0000000000000000000" # the workerly.in zone
alarm_email    = "alerts@workerly.in"
map_tile_url   = "https://tiles.example.com/{z}/{x}/{y}.png" # set to the chosen provider (CSP allows its origin)

db_instance_class = "db.t4g.small"
redis_node_type   = "cache.t4g.micro"
api_count         = 1
api_max_count     = 2
web_count         = 1

# Staging may run on the fake adapters (the API logs OTP codes for testers); production refuses to boot on them.
app_env = {
  SMS_ADAPTER           = "fake"
  PAYMENT_ADAPTER       = "fake"
  AI_ADAPTER            = "fake"
  AI_TRIAGE_ENABLED     = "true"
  AI_TRANSCRIBE_ENABLED = "true"
}
