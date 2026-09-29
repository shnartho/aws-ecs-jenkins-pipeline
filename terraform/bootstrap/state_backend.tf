# Remote state bucket for every workload stack under terraform/envs/*. Deliberately managed here,
# not by the workload stacks themselves - see the rationale comment at the top of providers.tf.
# NOTE: prevent_destroy is temporarily removed below to allow tearing down a wrong-account bootstrap
# apply - restore it (uncomment the lifecycle block) once you're on the correct account for real use.
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = merge(var.tags, { Name = var.state_bucket_name })
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State locking table. Terraform 1.8 (pinned in this repo's .terraform-version / CI) predates
# native S3 locking (added in 1.10), so DynamoDB is still required here.
resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, { Name = var.lock_table_name })
}
