# Shared logging bucket for ALB access logs, ECS container logs exports, and Jenkins pipeline logs -
# the assignment's single centralized-logging requirement.
# checkov:skip=CKV_AWS_18: This bucket IS the centralized log destination; enabling access logging on
# it would create a recursive logging loop against itself.
resource "aws_s3_bucket" "logs" {
  bucket = "broken-cloud-pipeline-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, { Name = "broken-cloud-pipeline-logs" })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning + noncurrent-version expiration protects against accidental overwrite/delete without
# letting old versions accumulate cost indefinitely.
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Expires current log objects after 30 days and old versions after 7 - bounds storage cost growth
# (this partially offsets, but does not eliminate, the deliberate Jenkins log-volume flaw).
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Grants only the AWS-managed ELB log-delivery account write access, scoped to this bucket's ALB
# log prefix - least privilege for a cross-account AWS service writing into our bucket.
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket_policy.json
}

data "aws_iam_policy_document" "logs_bucket_policy" {
  statement {
    sid    = "AllowALBLogDelivery"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/alb-logs/*"]
  }
}
