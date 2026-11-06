env            = "production"
domain         = "workerly.in"
hosted_zone_id = "Z0000000000000000000"
alarm_email    = "alerts@workerly.in"
map_tile_url   = "https://tiles.example.com/{z}/{x}/{y}.png" # set to the chosen provider

nat_per_az          = true
db_instance_class   = "db.t4g.medium"
db_multi_az         = true
redis_node_type     = "cache.t4g.small"
redis_replicas      = 1
api_count           = 2
api_max_count       = 6
web_count           = 2
admin_allowed_cidrs = [] # e.g. ["203.0.113.0/24"] for the office / VPN

# Decisions D3-D6 land here. Production will not boot on fake SMS or payments.
app_env = {
  SMS_ADAPTER           = "msg91" # D6. Put MSG91_AUTH_KEY in the app secret; template ids below.
  MSG91_TEMPLATE_OTP                      = ""
  MSG91_TEMPLATE_LEAD_NEW                 = ""
  MSG91_TEMPLATE_QUOTE_ACCEPTED           = ""
  MSG91_TEMPLATE_WORKER_APPROVED          = ""
  MSG91_TEMPLATE_WORKER_CHANGES_REQUESTED = ""
  MSG91_TEMPLATE_WORKER_REJECTED          = ""
  PAYMENT_ADAPTER       = "razorpay"
  RAZORPAY_KEY_ID       = "rzp_live_xxxxxxxxxxxx"
  AI_ADAPTER            = "fake"
  AI_TRIAGE_ENABLED     = "false"
  AI_TRANSCRIBE_ENABLED = "false"
}
