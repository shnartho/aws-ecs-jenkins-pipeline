# Jenkins ALB in the Jenkins VPC (10.41.0.0/16) - public HTTPS, restricted to the configured allowed
# countries via the WAFv2 Web ACL defined in waf.tf. The security group intentionally still allows
# 0.0.0.0/0 on 443, because Security Groups cannot filter by country - WAF is the actual enforcement
# point here (see waf.tf and modules/public-alb for the full rationale).
module "jenkins_alb" {
  source = "../../modules/public-alb"

  name              = "jenkins"
  vpc_id            = module.jenkins_vpc.vpc_id
  public_subnet_ids = module.jenkins_vpc.public_subnets
  certificate_arn   = var.certificate_arn
  allowed_cidrs     = ["0.0.0.0/0"]
  attach_waf        = true
  waf_web_acl_arn   = aws_wafv2_web_acl.jenkins_geo.arn
  container_port    = 8080
  health_check_path = "/login"
  logs_bucket       = aws_s3_bucket.logs.bucket
  logs_prefix       = "alb-logs/jenkins"
  tags              = local.common_tags
}

# Least-privilege permissions Jenkins needs to invoke the isolated builder and deploy the app.
data "aws_iam_policy_document" "jenkins_task_extra" {
  statement {
    sid    = "RunAppImageBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds",
    ]
    resources = [aws_codebuild_project.app_image.arn]
  }

  statement {
    sid    = "ECSDeployAppService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [
      module.app_ecs.service_arn,
      module.app_ecs.cluster_arn,
    ]
  }

  statement {
    sid    = "ECSUnscopedTaskDefinitionActions"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"] # AWS does not support resource-level restriction for these actions
  }

  statement {
    sid       = "PassAppTaskRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [module.app_ecs.task_role_arn, module.app_ecs.task_execution_role_arn]
  }

  statement {
    sid     = "WritePipelineLogs"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.logs.arn}/codebuild-sources/*",
      "${aws_s3_bucket.logs.arn}/pipeline-logs/*",
    ]
  }

  statement {
    sid       = "ReadBuildLogs"
    effect    = "Allow"
    actions   = ["logs:GetLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app_image_builder.arn}:*"]
  }

  statement {
    sid       = "PublishPipelineNotifications"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

# Jenkins ECS service: a versioned non-root controller image; Docker builds run in CodeBuild.
module "jenkins_ecs" {
  source = "../../modules/ecs-service"

  name               = "jenkins"
  vpc_id             = module.jenkins_vpc.vpc_id
  private_subnet_ids = module.jenkins_vpc.private_subnets
  instance_type      = "t3.micro"
  instance_count     = 2
  container_image    = "${aws_ecr_repository.jenkins.repository_url}:2.568.3-lts-jdk21-tools-v1"
  container_port     = 8080
  desired_count      = 1
  # Jenkins itself is sized above the assignment's illustrative 256/512 example (which the app's
  # Terraform flaw already exercises) - a stock Jenkins controller is not usably stable at 256/512.
  # Memory capped at 700 (not 1024): a t3.micro's full 1024 MiB is never fully registered as
  # available to ECS (OS/agent overhead reserves some), so a 1024 MiB reservation can never be
  # placed on any t3.micro instance - this was a real bug (RESOURCE:MEMORY placement failures),
  # not one of the three documented flaws, and had to be fixed for Jenkins to start at all.
  task_cpu              = 512
  task_memory           = 700
  target_group_arn      = module.jenkins_alb.target_group_arn
  alb_security_group_id = module.jenkins_alb.security_group_id
  # Jenkins plugin initialization can take several minutes after a cold start.
  health_check_grace_period_seconds = 300
  # Persists /var/jenkins_home to EFS (efs-jenkins.tf) so job configs/build history survive
  # task replacements - the container filesystem is otherwise wiped on every redeploy.
  efs_file_system_id = aws_efs_file_system.jenkins_home.id
  efs_mount_path     = "/var/jenkins_home"
  container_environment = {
    APP_ALB_HTTPS_URL      = var.domain_name == null ? module.app_alb.alb_dns_name : "app.${var.domain_name}"
    APP_ECS_CLUSTER_NAME   = module.app_ecs.cluster_name
    APP_ECS_SERVICE_NAME   = module.app_ecs.service_name
    CODEBUILD_PROJECT_NAME = aws_codebuild_project.app_image.name
    ECR_REPOSITORY_URL     = aws_ecr_repository.app.repository_url
    PIPELINE_LOGS_BUCKET   = aws_s3_bucket.logs.bucket
    SNS_TOPIC_ARN          = aws_sns_topic.alerts.arn
  }
  task_role_extra_policy_json   = data.aws_iam_policy_document.jenkins_task_extra.json
  attach_task_role_extra_policy = true
  log_retention_days            = 14
  tags                          = local.common_tags
}
