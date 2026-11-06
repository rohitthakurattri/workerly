terraform {
  required_version = ">= 1.6"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.70" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # State lives in S3 with locking; the bucket and table are created once by hand (see README):
  #   terraform init -backend-config=environments/<env>.backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "workerly", Environment = var.env, ManagedBy = "terraform" }
  }
}
