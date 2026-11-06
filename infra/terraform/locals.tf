locals {
  name = "workerly-${var.env}"
  hosts = {
    customer = var.domain
    worker   = "pro.${var.domain}"
    admin    = "admin.${var.domain}"
    api      = "api.${var.domain}"
  }
  app_origins = join(",", [for k in ["customer", "worker", "admin"] : "https://${local.hosts[k]}"])
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  production  = var.env == "production"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
