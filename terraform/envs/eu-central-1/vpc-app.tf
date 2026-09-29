# Application VPC (10.40.0.0/16): hosts the public-facing app ALB and its private ECS cluster.
module "app_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "app-vpc"
  cidr = var.app_vpc_cidr

  azs             = var.azs
  public_subnets  = [cidrsubnet(var.app_vpc_cidr, 8, 0), cidrsubnet(var.app_vpc_cidr, 8, 1)]
  private_subnets = [cidrsubnet(var.app_vpc_cidr, 8, 10), cidrsubnet(var.app_vpc_cidr, 8, 11)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Single NAT Gateway (tradeoff): halves NAT cost vs. one-per-AZ; accepted for this non-production
  # exercise (private-subnet egress loses redundancy if that single AZ has an outage). See README.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Public-subnet NACL restricts inbound to HTTPS + ephemeral return traffic only, mirroring the ALB
  # security group. Private-subnet NACLs are left at module defaults (allow all intra-VPC) since the
  # real reachability boundary there is already enforced by security groups.
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
