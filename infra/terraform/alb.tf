# One load balancer, routed by host name: api., the customer domain (and www.), pro., admin.
resource "aws_lb" "main" {
  name                       = local.name
  load_balancer_type         = "application"
  subnets                    = aws_subnet.public[*].id
  security_groups            = [aws_security_group.alb.id]
  idle_timeout               = 120 # Action Cable websockets stay open
  drop_invalid_header_fields = true
  enable_deletion_protection = local.production
}

locals {
  targets = {
    api      = { health = "/up", hosts = [local.hosts.api] }
    customer = { health = "/manifest.webmanifest", hosts = [local.hosts.customer, "www.${local.hosts.customer}"] }
    worker   = { health = "/manifest.webmanifest", hosts = [local.hosts.worker] }
    admin    = { health = "/manifest.webmanifest", hosts = [local.hosts.admin] }
  }
}

resource "aws_lb_target_group" "app" {
  for_each             = local.targets
  name                 = "${local.name}-${each.key}"
  port                 = 3000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30
  health_check {
    path                = each.value.health
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "app" {
  for_each     = local.targets
  listener_arn = aws_lb_listener.https.arn
  priority     = 10 + index(keys(local.targets), each.key)
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
  condition {
    host_header {
      values = each.value.hosts
    }
  }
  # The admin app can be limited to an office / VPN range.
  dynamic "condition" {
    for_each = each.key == "admin" && length(var.admin_allowed_cidrs) > 0 ? [1] : []
    content {
      source_ip {
        values = var.admin_allowed_cidrs
      }
    }
  }
}

# --- WAF: AWS managed rules and a per-IP rate limit in front of everything ----------------------
resource "aws_wafv2_web_acl" "main" {
  name  = local.name
  scope = "REGIONAL"
  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 0
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000 # requests per 5 minutes per IP; Rack::Attack does the finer limits
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-rate"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = { common = 1, known-bad-inputs = 2, sqli = 3 }
    content {
      name     = rule.key
      priority = rule.value
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name = {
            common           = "AWSManagedRulesCommonRuleSet"
            known-bad-inputs = "AWSManagedRulesKnownBadInputsRuleSet"
            sqli             = "AWSManagedRulesSQLiRuleSet"
          }[rule.key]
          # Photo, voice-note and document uploads are larger than the common set's 8 KB body rule.
          dynamic "rule_action_override" {
            for_each = rule.key == "common" ? ["SizeRestrictions_BODY"] : []
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name}-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
