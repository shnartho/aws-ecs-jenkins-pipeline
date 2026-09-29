# Jenkins VPC (10.41.0.0/16): hosts the geo-restricted Jenkins ALB and its private ECS cluster.
module "jenkins_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "jenkins-vpc"
  cidr = var.jenkins_vpc_cidr

  azs             = var.azs
  public_subnets  = [cidrsubnet(var.jenkins_vpc_cidr, 8, 0), cidrsubnet(var.jenkins_vpc_cidr, 8, 1)]
  private_subnets = [cidrsubnet(var.jenkins_vpc_cidr, 8, 10), cidrsubnet(var.jenkins_vpc_cidr, 8, 11)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Single NAT Gateway (tradeoff): see vpc-app.tf for the same reasoning.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Same HTTPS-only public NACL pattern as the app VPC.
  public_dedicated_network_acl = true
  public_inbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number = 110
      rule_action = "allow"
      from_port   = 1024
      to_port     = 65535
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
    },
  ]
  public_outbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
    },
  ]

  tags = local.common_tags
}
