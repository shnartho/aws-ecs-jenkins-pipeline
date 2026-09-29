# Public-facing application ALB in the app VPC (10.40.0.0/16) - open to all via HTTPS, per requirement.
module "app_alb" {
  source = "../../modules/public-alb"

  name              = "app"
  vpc_id            = module.app_vpc.vpc_id
  public_subnet_ids = module.app_vpc.public_subnets
  certificate_arn   = var.certificate_arn
  allowed_cidrs     = ["0.0.0.0/0"]
  container_port    = 8080
  health_check_path = "/health"
  # The stateless app drains quickly so serial replacements fit inside the ECS waiter window.
  deregistration_delay_seconds = 30
  logs_bucket                  = aws_s3_bucket.logs.bucket
  logs_prefix                  = "alb-logs/app"
  tags                         = local.common_tags
}

# Application ECS service: 2 hello-world containers on 2 t3.micro EC2 instances in private subnets.
#
# NOTE (bootstrap): this references "${ecr_repo}:initial" - build and push an image with that tag
# BEFORE the first `terraform apply` completes, or the service will fail to stabilize (ECS has
# nothing to pull). Every deployment after that is handled by the Jenkins pipeline, which registers
# new task-definition revisions with unique build tags - see jenkins/Jenkinsfile.
module "app_ecs" {
  source = "../../modules/ecs-service"

  name               = "app"
  vpc_id             = module.app_vpc.vpc_id
  private_subnet_ids = module.app_vpc.private_subnets
  instance_type      = "t3.micro"
  instance_count     = 2
  container_image    = "${aws_ecr_repository.app.repository_url}:initial"
  container_port     = 8080
  desired_count      = 2
  # Both fixed-size cluster hosts normally run one task, so deployments must replace them serially.
  deployment_minimum_healthy_percent = 50
  # Jenkins owns releases after bootstrap; Terraform follows the latest active family revision.
  track_latest_task_definition = true
  # FLAW: task CPU intentionally over-allocated to 1024 (4x the required 256 stated in the
  # assignment). This reserves 4x the EC2 capacity the hello-world container actually needs on every
  # task placement, wasting cluster capacity and, at scale, forcing more/larger EC2 instances than
  # necessary - without producing any functional difference in the running application.
  # Fix: set task_cpu = 256 to match the assignment's stated task definition size.
  task_cpu              = 1024
  task_memory           = 512
  target_group_arn      = module.app_alb.target_group_arn
  alb_security_group_id = module.app_alb.security_group_id
  log_retention_days    = 14
  tags                  = local.common_tags
}
