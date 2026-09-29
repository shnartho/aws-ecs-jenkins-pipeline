locals {
  ecs_ami_id = jsondecode(data.aws_ssm_parameter.ecs_ami.value)["image_id"]

  mount_points = var.efs_file_system_id == null ? [] : [
    {
      sourceVolume  = "efs-data"
      containerPath = var.efs_mount_path
      readOnly      = false
    }
  ]
}

# --- IAM: EC2 container instance role (ECS agent + SSM, no SSH needed) ---

data "aws_iam_policy_document" "instance_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# EC2 instance role: lets the ECS agent register the host with the cluster and allows SSM Session
# Manager access instead of SSH (no inbound port 22 anywhere in this architecture).
resource "aws_iam_role" "instance" {
  name               = "${var.name}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "instance_ecs" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-ecs-instance-profile"
  role = aws_iam_role.instance.name
}

# --- Networking: security group for the ECS EC2 instances ---

# ECS instances only accept traffic from their own ALB, on the dynamic host-port range used by
# bridge-mode task placement; all outbound is allowed (egress-only restriction is out of scope here).
resource "aws_security_group" "instances" {
  name        = "${var.name}-ecs-instances-sg"
  description = "Allow the ALB to reach ECS dynamic host ports; allow all outbound"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ALB to ECS dynamic port range"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-ecs-instances-sg" })
}

# --- EC2 capacity: launch template + fixed-size Auto Scaling group ---

# Launch template for ECS container instances; IMDSv2 is required to reduce SSRF-based credential theft.
resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-ecs-"
  image_id      = local.ecs_ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  vpc_security_group_ids = [aws_security_group.instances.id]

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.name}-cluster >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-ecs-instance" })
  }
}

# Fixed-size ASG (min = max = desired) providing the 2 free-tier EC2 instances required per cluster.
resource "aws_autoscaling_group" "this" {
  name                  = "${var.name}-ecs-asg"
  min_size              = var.instance_count
  max_size              = var.instance_count
  desired_capacity      = var.instance_count
  vpc_zone_identifier   = var.private_subnet_ids
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs-instance"
    propagate_at_launch = true
  }
}

# --- ECS cluster + capacity provider (ties the ASG to the cluster) ---

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  tags = merge(var.tags, { Name = "${var.name}-cluster" })
}

resource "aws_ecs_capacity_provider" "this" {
  name = "${var.name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-cp" })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }
}

# --- IAM: ECS task execution role (pull image, write logs) + task role (app permissions) ---

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: used by the ECS agent itself to pull from ECR and ship logs to CloudWatch.
resource "aws_iam_role" "task_execution" {
  name               = "${var.name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: used by the application code itself; empty by default, extended per caller via
# task_role_extra_policy_json (e.g. Jenkins is granted ECR push + ECS deploy permissions here).
resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task_extra" {
  # A literal bool, not a `== null` check on the (possibly not-yet-known) policy JSON itself - the
  # JSON can reference other same-apply resources' attributes without breaking `count`'s evaluation.
  count  = var.attach_task_role_extra_policy ? 1 : 0
  name   = "${var.name}-task-extra-policy"
  role   = aws_iam_role.task.id
  policy = var.task_role_extra_policy_json
}

# --- Logging ---

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Name = "${var.name}-log-group" })
}

# --- Task definition + service ---

# Task definition for this service. NOTE: the app instantiation of this module (app.tf) intentionally
# overrides task_cpu to 1024 - that is the documented Terraform FLAW, not a defect in this module.
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # Persists container state (e.g. Jenkins job configs/build history) across task replacements -
  # without this, a plain ECS task's filesystem is wiped every time a new task is placed.
  dynamic "volume" {
    for_each = var.efs_file_system_id == null ? [] : [1]
    content {
      name = "efs-data"
      efs_volume_configuration {
        file_system_id     = var.efs_file_system_id
        root_directory     = "/"
        transit_encryption = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    merge(
      {
        name      = var.name
        image     = var.container_image
        essential = true
        portMappings = [
          {
            containerPort = var.container_port
            hostPort      = 0
            protocol      = "tcp"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this.name
            "awslogs-region"        = data.aws_region.current.name
            "awslogs-stream-prefix" = var.name
          }
        }
      },
      length(var.container_environment) == 0 ? {} : {
        environment = [for name, value in var.container_environment : { name = name, value = value }]
      },
      length(local.mount_points) == 0 ? {} : { mountPoints = local.mount_points }
    )
  ])

  tags = merge(var.tags, { Name = "${var.name}-task-def" })
}

# Resolves externally registered revisions when the deployment pipeline owns service releases.
data "aws_ecs_task_definition" "latest" {
  count = var.track_latest_task_definition ? 1 : 0

  task_definition = aws_ecs_task_definition.this.family
}

resource "aws_ecs_service" "this" {
  name                              = var.name
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = var.track_latest_task_definition ? data.aws_ecs_task_definition.latest[0].arn : aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.name
    container_port   = var.container_port
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]

  tags = merge(var.tags, { Name = "${var.name}-service" })
}
