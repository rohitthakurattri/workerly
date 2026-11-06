output "urls" {
  value = { for k, h in local.hosts : k => "https://${h}" }
}

output "ecr_repositories" {
  value = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "files_bucket" {
  value = aws_s3_bucket.files.bucket
}

output "app_secret_arn" {
  description = "Fill the third-party keys here (Razorpay, SMS, OpenAI, VAPID)."
  value       = aws_secretsmanager_secret.app.arn
}

# What the deploy workflow needs to run the migration task.
output "deploy" {
  value = {
    cluster          = aws_ecs_cluster.main.name
    migrate_task     = aws_ecs_task_definition.migrate.family
    subnets          = join(",", aws_subnet.private[*].id)
    security_group   = aws_security_group.app.id
    services         = keys(local.services)
    razorpay_webhook = "https://${local.hosts.api}/api/v1/webhooks/razorpay"
  }
}
