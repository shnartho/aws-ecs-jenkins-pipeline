# CodeBuild assumes this role only for isolated application image builds.
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

# Dedicated role for application builds; Jenkins cannot use these ECR permissions directly.
resource "aws_iam_role" "app_image_builder" {
  name               = "app-image-builder-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = local.common_tags
}

# Grants the builder source-read, log-write, and app-repository push access only.
data "aws_iam_policy_document" "app_image_builder" {
  statement {
    sid       = "ReadBuildSource"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.logs.arn}/codebuild-sources/*"]
  }

  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushAppImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid    = "WriteBuildLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.app_image_builder.arn}:*"]
  }
}

# Attaches the least-privilege application image build policy.
resource "aws_iam_role_policy" "app_image_builder" {
  name   = "app-image-builder-policy"
  role   = aws_iam_role.app_image_builder.id
  policy = data.aws_iam_policy_document.app_image_builder.json
}

# Retains build output long enough for operational diagnosis without unbounded log growth.
resource "aws_cloudwatch_log_group" "app_image_builder" {
  name              = "/aws/codebuild/app-image"
  retention_in_days = 14
  tags              = merge(local.common_tags, { Name = "app-image-build-logs" })
}

# Isolated Docker builder that accepts a Jenkins-uploaded source archive and immutable image tag.
# checkov:skip=CKV_AWS_316: Docker builds require privilege; it is isolated here from the controller.
resource "aws_codebuild_project" "app_image" {
  name         = "app-image"
  description  = "Builds and pushes immutable application images for the Jenkins deployment pipeline."
  service_role = aws_iam_role.app_image_builder.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  source {
    type = "NO_SOURCE"
    buildspec = yamlencode({
      version = 0.2
      phases = {
        pre_build = {
          commands = [
            "aws s3 cp s3://$SOURCE_BUCKET/$SOURCE_OBJECT /tmp/source.zip",
            "unzip -q /tmp/source.zip -d /tmp/source",
            "aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $IMAGE_REPOSITORY",
          ]
        }
        build = {
          commands = ["docker build --pull -t $IMAGE_REPOSITORY:$IMAGE_TAG -f /tmp/source/docker/app/Dockerfile /tmp/source/docker/app"]
        }
        post_build = {
          commands = ["docker push $IMAGE_REPOSITORY:$IMAGE_TAG"]
        }
      }
    })
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "SOURCE_BUCKET"
      value = aws_s3_bucket.logs.bucket
    }

    environment_variable {
      name  = "IMAGE_REPOSITORY"
      value = aws_ecr_repository.app.repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.app_image_builder.name
      stream_name = "build"
    }
  }

  tags = merge(local.common_tags, { Name = "app-image-builder" })
}