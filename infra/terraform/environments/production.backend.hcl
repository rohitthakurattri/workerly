bucket         = "workerly-terraform-state" # created once by hand, versioned and encrypted
key            = "production/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "workerly-terraform-locks"
encrypt        = true
