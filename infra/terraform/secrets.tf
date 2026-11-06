# Application secrets in one Secrets Manager JSON document, injected into the tasks by key.
# Internal secrets are generated here. Third-party keys (Razorpay, SMS, OpenAI, VAPID) start empty
# and are filled in the console or with `aws secretsmanager put-secret-value`; Terraform then
# leaves the value alone (ignore_changes).
locals {
  generated_secrets = ["SECRET_KEY_BASE", "JWT_SECRET", "OTP_PEPPER", "TOKEN_PEPPER",
  "AR_ENCRYPTION_PRIMARY_KEY", "AR_ENCRYPTION_DETERMINISTIC_KEY", "AR_ENCRYPTION_KEY_DERIVATION_SALT"]
  external_secrets = ["RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET", "OPENAI_API_KEY", "VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY",
  "MSG91_AUTH_KEY"]
}

resource "random_password" "generated" {
  for_each = toset(local.generated_secrets)
  length   = 64
  special  = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/app"
  recovery_window_in_days = local.production ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode(merge(
    { for k in local.generated_secrets : k => random_password.generated[k].result },
    { for k in local.external_secrets : k => "" },
    { REDIS_URL = "rediss://:${random_password.redis.result}@${aws_elasticache_replication_group.main.primary_endpoint_address}:6379" }
  ))
  lifecycle {
    ignore_changes = [secret_string]
  }
}
