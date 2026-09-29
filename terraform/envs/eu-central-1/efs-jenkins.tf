# Persistent storage for the Jenkins container's /var/jenkins_home - without this, a plain ECS
# task's filesystem is wiped on every task replacement (redeploys, crashes, host termination),
# losing job configs, build history, and the initial admin setup every time.
resource "aws_efs_file_system" "jenkins_home" {
  encrypted = true

  tags = merge(local.common_tags, { Name = "jenkins-home" })
}

# Only the Jenkins ECS instances may reach the filesystem, and only on the NFS port.
resource "aws_security_group" "jenkins_efs" {
  name        = "jenkins-efs-sg"
  description = "Allow NFS from Jenkins ECS instances only"
  vpc_id      = module.jenkins_vpc.vpc_id

  ingress {
    description     = "NFS from Jenkins ECS instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [module.jenkins_ecs.instance_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "jenkins-efs-sg" })
}

# One mount target per private subnet, so either AZ's instance can reach the filesystem.
resource "aws_efs_mount_target" "jenkins_home" {
  count = length(module.jenkins_vpc.private_subnets)

  file_system_id  = aws_efs_file_system.jenkins_home.id
  subnet_id       = module.jenkins_vpc.private_subnets[count.index]
  security_groups = [aws_security_group.jenkins_efs.id]
}
