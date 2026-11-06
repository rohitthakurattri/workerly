variable "env" {
  description = "staging or production"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.env)
    error_message = "env must be staging or production."
  }
}

variable "region" {
  description = "AWS region. Mumbai keeps customer data in India (DPDP Act)."
  type        = string
  default     = "ap-south-1"
}

variable "domain" {
  description = "Customer app domain; the others are pro., admin. and api. under it (e.g. workerly.in or staging.workerly.in)."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 zone that holds var.domain (records and certificate validation go here)."
  type        = string
}

variable "image_tag" {
  description = "Tag of the workerly-api and workerly-web images to run (the git SHA the deploy built)."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "nat_per_az" {
  description = "One NAT gateway per AZ (resilient) instead of one shared (cheaper)."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_allocated_storage" {
  type    = number
  default = 50
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "redis_replicas" {
  description = "Read replicas with automatic failover (0 = single node)."
  type        = number
  default     = 0
}

variable "api_count" {
  type    = number
  default = 2
}

variable "api_max_count" {
  type    = number
  default = 6
}

variable "jobs_count" {
  type    = number
  default = 1
}

variable "web_count" {
  description = "Tasks per web app (customer, worker, admin)."
  type        = number
  default     = 2
}

variable "admin_allowed_cidrs" {
  description = "If set, admin.<domain> only answers these source ranges (office / VPN)."
  type        = list(string)
  default     = []
}

variable "alarm_email" {
  description = "Where CloudWatch alarms are sent."
  type        = string
}

variable "map_tile_url" {
  description = "Leaflet tile URL template from a commercial provider (OpenStreetMap's own servers are not for production)."
  type        = string
}

variable "app_env" {
  description = "Extra non-secret environment for the API and jobs (adapters, feature flags, D3-D6 settings)."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  type    = number
  default = 30
}
