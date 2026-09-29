terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

# Primary provider for all region-scoped resources (Frankfurt, per the task's region requirement).
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = local.common_tags
  }
}

# AWS only publishes billing/estimated-charges metrics in us-east-1 regardless of the account's
# operating region - this alias exists solely for the cost alarm and its SNS topic.
provider "aws" {
  alias  = "billing"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}
