# Remote state: S3 backend with DynamoDB locking. Bucket/table/role are created by the separate
# terraform/bootstrap module (never by this stack - see terraform/bootstrap/providers.tf for why).
# Account-specific bucket and table names are supplied from ignored backend.hcl configuration.
terraform {
  backend "s3" {
    key     = "broken-cloud-pipeline/eu-central-1/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
