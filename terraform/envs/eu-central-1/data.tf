data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# The ELB regional log-delivery account, needed for the S3 bucket policy; it varies per region.
data "aws_elb_service_account" "main" {}
