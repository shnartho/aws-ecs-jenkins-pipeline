# Platform bootstrap layer - SEPARATE from terraform/envs/*.
#
# This module creates the two things every workload stack in this repo depends on but cannot
# create for itself: the Terraform remote-state backend (S3 + DynamoDB) and the IAM role that
# workload Terraform runs assume to deploy. It is applied once, by hand, with elevated
# credentials - not by CI, not automatically, and not as part of any workload `terraform apply`.
#
# Why this is a separate module (and would be a separate repository in a real org):
#   - A workload stack that could create/modify its own deploy role would be a privilege-escalation
#     hole - anyone able to change that code could grant themselves broader permissions.
#   - This module intentionally uses LOCAL state, because it creates the remote-state backend that
#     everything else depends on; it cannot depend on the backend it is responsible for creating.
#   - Changes here should be rare and reviewed more strictly than day-to-day workload changes.
#
# After the first successful apply, consider migrating this module's own state into the bucket it
# just created (under a distinct key, e.g. "bootstrap/terraform.tfstate") so a lost laptop doesn't
# mean a lost state file - see the migration note at the bottom of this file.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# --- Optional state migration (do this manually, after the first apply) ---
# 1. terraform apply                     # creates the bucket/table with LOCAL state
# 2. Uncomment a backend "s3" block below, filling in this module's own outputs
# 3. terraform init -migrate-state       # moves local state into the bucket, under a distinct key
#
# terraform {
#   backend "s3" {
#     bucket         = "REPLACE_WITH_STATE_BUCKET_OUTPUT"
#     key            = "bootstrap/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "REPLACE_WITH_LOCK_TABLE_OUTPUT"
#     encrypt        = true
#   }
# }
