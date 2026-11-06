resource "aws_ecs_cluster" "main" {
  name = local.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "svc" {
  for_each          = toset(["api", "jobs", "migrate", "customer", "worker", "admin"])
  name              = "/workerly/${var.env}/${each.key}"
  retention_in_days = var.log_retention_days
}

# --- IAM ----------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Pulls images, writes logs, reads the secrets it injects.
resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.app.arn, aws_db_instance.main.master_user_secret[0].secret_arn]
    }]
  })
}

# What the Rails code itself may do: read and write its own bucket, nothing else.
resource "aws_iam_role" "rails" {
  name               = "${local.name}-rails"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy" "rails_files" {
  role = aws_iam_role.rails.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.files.arn}/*" },
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.files.arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.files.arn }
    ]
  })
}

# Web (Nuxt) tasks need no AWS access at all.
resource "aws_iam_role" "web" {
  name               = "${local.name}-web"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# --- Task definitions ---------------------------------------------------------------------------
locals {
  api_image = "${aws_ecr_repository.app["api"].repository_url}:${var.image_tag}"
  web_image = "${aws_ecr_repository.app["web"].repository_url}:${var.image_tag}"

  rails_env = merge({
    RAILS_ENV         = "production"
    DEPLOY_ENV        = var.env
    RAILS_LOG_LEVEL   = "info"
    APP_HOSTS         = local.hosts.api
    APP_ORIGINS       = local.app_origins
    ACTION_CABLE_URL  = "wss://${local.hosts.api}/cable"
    AWS_REGION        = var.region
    S3_PRIVATE_BUCKET = aws_s3_bucket.files.bucket
    # sslmode=require: encrypted to RDS (rds.force_ssl). The password comes from PGPASSWORD.
    DATABASE_URL      = "postgis://${aws_db_instance.main.username}@${aws_db_instance.main.address}:5432/${aws_db_instance.main.db_name}?sslmode=require"
    RAILS_MAX_THREADS = "5"
    WEB_CONCURRENCY   = "2"
  }, var.app_env)

  rails_secrets = concat(
    [for k in concat(local.generated_secrets, local.external_secrets, ["REDIS_URL"]) : { name = k, valueFrom = "${aws_secretsmanager_secret.app.arn}:${k}::" }],
    [{ name = "PGPASSWORD", valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::" }]
  )

  rails_container = {
    image                  = local.api_image
    essential              = true
    environment            = [for k, v in local.rails_env : { name = k, value = v }]
    secrets                = local.rails_secrets
    readonlyRootFilesystem = false
    linuxParameters        = { initProcessEnabled = true }
  }

  log_config = { for svc, group in aws_cloudwatch_log_group.svc : svc => {
    logDriver = "awslogs"
    options   = { "awslogs-group" = group.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = svc }
  } }

  web_apps = ["customer", "worker", "admin"]
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.rails.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([merge(local.rails_container, {
    name             = "api"
    portMappings     = [{ containerPort = 3000, protocol = "tcp" }]
    logConfiguration = local.log_config["api"]
  })])
}

resource "aws_ecs_task_definition" "jobs" {
  family                   = "${local.name}-jobs"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.rails.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([merge(local.rails_container, {
    name             = "jobs"
    command          = ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
    logConfiguration = local.log_config["jobs"]
  })])
}

# One-off: the deploy runs this (bin/rails db:prepare) and waits for it before rolling the services.
resource "aws_ecs_task_definition" "migrate" {
  family                   = "${local.name}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.rails.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([merge(local.rails_container, {
    name             = "migrate"
    command          = ["bin/rails", "db:prepare"]
    logConfiguration = local.log_config["migrate"]
  })])
}

resource "aws_ecs_task_definition" "web" {
  for_each                 = toset(local.web_apps)
  family                   = "${local.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.web.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([{
    name         = each.key
    image        = local.web_image
    essential    = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment = [for k, v in {
      APP_TARGET                    = each.key
      NUXT_PUBLIC_API_BASE          = "https://${local.hosts.api}/api/v1"
      NUXT_PUBLIC_APP_URLS_CUSTOMER = "https://${local.hosts.customer}"
      NUXT_PUBLIC_APP_URLS_WORKER   = "https://${local.hosts.worker}"
      NUXT_PUBLIC_APP_URLS_ADMIN    = "https://${local.hosts.admin}"
      NUXT_PUBLIC_ASSET_ORIGINS     = "https://${aws_s3_bucket.files.bucket_regional_domain_name}"
      NUXT_PUBLIC_MAP_TILE_URL      = var.map_tile_url
    } : { name = k, value = v }]
    logConfiguration = local.log_config[each.key]
  }])
}

# --- Services -----------------------------------------------------------------------------------
locals {
  services = merge(
    { api = { task = aws_ecs_task_definition.api.arn, count = var.api_count, tg = aws_lb_target_group.app["api"].arn, container = "api" } },
    { jobs = { task = aws_ecs_task_definition.jobs.arn, count = var.jobs_count, tg = null, container = "jobs" } },
    { for app in local.web_apps : app => { task = aws_ecs_task_definition.web[app].arn, count = var.web_count, tg = aws_lb_target_group.app[app].arn, container = app } }
  )
}

resource "aws_ecs_service" "app" {
  for_each                          = local.services
  name                              = each.key
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = each.value.task
  desired_count                     = each.value.count
  launch_type                       = "FARGATE"
  enable_execute_command            = !local.production
  health_check_grace_period_seconds = each.value.tg == null ? null : 60
  propagate_tags                    = "SERVICE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.value.tg == null ? [] : [each.value.tg]
    content {
      target_group_arn = load_balancer.value
      container_name   = each.value.container
      container_port   = 3000
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count] # autoscaling owns it once running
  }
  depends_on = [aws_lb_listener.https]
}

resource "aws_appautoscaling_target" "api" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app["api"].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.api_count
  max_capacity       = var.api_max_count
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${local.name}-api-cpu"
  service_namespace  = aws_appautoscaling_target.api.service_namespace
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    target_value = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
