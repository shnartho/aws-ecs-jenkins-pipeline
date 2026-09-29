# Free S3 gateway endpoints keep S3-bound traffic (ALB/ECS/pipeline log writes, ECR image layer
# storage) off the NAT Gateway, reducing NAT data-processing charges at zero additional hourly cost.
# Interface endpoints for ECR/CloudWatch/SSM were evaluated and rejected - see README "Cost" section:
# at this exercise's traffic volume they would cost more per month than the NAT Gateway they'd offset.
resource "aws_vpc_endpoint" "app_s3" {
  vpc_id          = module.app_vpc.vpc_id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = concat(module.app_vpc.private_route_table_ids, module.app_vpc.public_route_table_ids)

  tags = merge(local.common_tags, { Name = "app-s3-endpoint" })
}

resource "aws_vpc_endpoint" "jenkins_s3" {
  vpc_id          = module.jenkins_vpc.vpc_id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = concat(module.jenkins_vpc.private_route_table_ids, module.jenkins_vpc.public_route_table_ids)

  tags = merge(local.common_tags, { Name = "jenkins-s3-endpoint" })
}
