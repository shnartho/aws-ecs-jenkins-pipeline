# VPC peering connection enabling communication between the app and Jenkins VPCs, as explicitly
# required by the task (no additional functional need beyond satisfying that explicit requirement -
# the Jenkins pipeline deploys via public AWS APIs, not a direct network path - see README).
resource "aws_vpc_peering_connection" "app_to_jenkins" {
  vpc_id      = module.app_vpc.vpc_id
  peer_vpc_id = module.jenkins_vpc.vpc_id
  auto_accept = true

  tags = merge(local.common_tags, { Name = "app-jenkins-peering" })
}

# Route from the app VPC's private subnets to the Jenkins VPC over the peering connection.
resource "aws_route" "app_private_to_jenkins" {
  count = length(module.app_vpc.private_route_table_ids)

  route_table_id            = module.app_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = var.jenkins_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_jenkins.id
}

# Route from the Jenkins VPC's private subnets to the app VPC over the peering connection.
resource "aws_route" "jenkins_private_to_app" {
  count = length(module.jenkins_vpc.private_route_table_ids)

  route_table_id            = module.jenkins_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = var.app_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_jenkins.id
}
