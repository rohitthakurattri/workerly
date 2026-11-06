resource "aws_sns_topic" "alarms" {
  name = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  alb_dim = { LoadBalancer = aws_lb.main.arn_suffix }
  alarms = {
    "alb-5xx" = {
      description = "Load balancer or app answered 5xx more than 20 times in 5 minutes"
      namespace   = "AWS/ApplicationELB", metric = "HTTPCode_Target_5XX_Count", stat = "Sum", threshold = 20, op = "GreaterThanThreshold", dims = local.alb_dim
    }
    "api-latency" = {
      description = "API p95 above 1.5 s for 10 minutes"
      namespace   = "AWS/ApplicationELB", metric = "TargetResponseTime", stat = "p95", threshold = 1.5, op = "GreaterThanThreshold", periods = 2
      dims        = merge(local.alb_dim, { TargetGroup = aws_lb_target_group.app["api"].arn_suffix })
    }
    "api-unhealthy" = {
      description = "No healthy API task behind the load balancer"
      namespace   = "AWS/ApplicationELB", metric = "HealthyHostCount", stat = "Minimum", threshold = 1, op = "LessThanThreshold"
      dims        = merge(local.alb_dim, { TargetGroup = aws_lb_target_group.app["api"].arn_suffix })
    }
    "jobs-down" = {
      description = "The Sidekiq service has no running task (OTP SMS, matching and notifications stop)"
      namespace   = "ECS/ContainerInsights", metric = "RunningTaskCount", stat = "Minimum", threshold = 1, op = "LessThanThreshold"
      dims        = { ClusterName = aws_ecs_cluster.main.name, ServiceName = "jobs" }
    }
    "db-cpu" = {
      description = "Database CPU above 80% for 15 minutes"
      namespace   = "AWS/RDS", metric = "CPUUtilization", stat = "Average", threshold = 80, op = "GreaterThanThreshold", periods = 3
      dims        = { DBInstanceIdentifier = aws_db_instance.main.identifier }
    }
    "db-storage" = {
      description = "Database has under 5 GB free"
      namespace   = "AWS/RDS", metric = "FreeStorageSpace", stat = "Minimum", threshold = 5368709120, op = "LessThanThreshold"
      dims        = { DBInstanceIdentifier = aws_db_instance.main.identifier }
    }
    "redis-memory" = {
      description = "Redis memory above 80% (noeviction: Sidekiq would start failing)"
      namespace   = "AWS/ElastiCache", metric = "DatabaseMemoryUsagePercentage", stat = "Maximum", threshold = 80, op = "GreaterThanThreshold"
      dims        = { ReplicationGroupId = aws_elasticache_replication_group.main.id }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "main" {
  for_each            = local.alarms
  alarm_name          = "${local.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  dimensions          = each.value.dims
  statistic           = contains(["Sum", "Average", "Minimum", "Maximum"], each.value.stat) ? each.value.stat : null
  extended_statistic  = contains(["Sum", "Average", "Minimum", "Maximum"], each.value.stat) ? null : each.value.stat
  period              = 300
  evaluation_periods  = lookup(each.value, "periods", 1)
  threshold           = each.value.threshold
  comparison_operator = each.value.op
  treat_missing_data  = each.key == "alb-5xx" ? "notBreaching" : "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}
