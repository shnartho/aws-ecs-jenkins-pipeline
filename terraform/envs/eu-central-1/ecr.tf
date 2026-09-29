# Private ECR repository storing the application's container images, built and pushed by the
# Jenkins pipeline (Jenkins itself is pulled directly from Docker Hub, per the task's literal wording).
resource "aws_ecr_repository" "app" {
  name                 = "broken-cloud-pipeline/app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, { Name = "app-ecr-repo" })
}

# Private ECR repository for the versioned Jenkins controller image built from docker/jenkins.
resource "aws_ecr_repository" "jenkins" {
  name                 = "broken-cloud-pipeline/jenkins"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, { Name = "jenkins-ecr-repo" })
}

# Bounds storage cost: expire untagged images quickly and cap the number of retained tagged images.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 build-tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["build-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Bounds controller-image storage while retaining several known-good versions for rollback.
resource "aws_ecr_lifecycle_policy" "jenkins" {
  repository = aws_ecr_repository.jenkins.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 5 controller images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
