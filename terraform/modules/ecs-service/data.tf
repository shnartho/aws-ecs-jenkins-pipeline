data "aws_region" "current" {}

# Latest Amazon-maintained ECS-optimized AMI, resolved dynamically so the module never pins a stale AMI ID.
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}
