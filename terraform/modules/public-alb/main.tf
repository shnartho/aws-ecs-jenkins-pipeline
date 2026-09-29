# Security group for the ALB: HTTPS inbound only, all outbound (per the task's explicit SG rules).
# 0.0.0.0/0 on 443 is intentional here - the app ALB must be open to all, and the Jenkins ALB layers a
# WAFv2 geo-match rule on top since Security Groups cannot filter by country (see waf_web_acl_arn).
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allow HTTPS inbound only; all outbound"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

# Public-facing Application Load Balancer.
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # ALB access logs feed the shared logging bucket required by the assignment.
  access_logs {
    bucket  = var.logs_bucket
    prefix  = var.logs_prefix
    enabled = true
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

# Target group receiving traffic from ECS tasks registered via the ECS service's dynamic port mapping.
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = var.deregistration_delay_seconds

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = merge(var.tags, { Name = "${var.name}-tg" })
}

# HTTPS-only listener; the task explicitly forbids any inbound port other than 443.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Optional WAF association: used only by the Jenkins ALB to enforce country-based access control that
# Security Groups are structurally unable to express (SGs match CIDRs, not geography).
resource "aws_wafv2_web_acl_association" "this" {
  # A literal bool, not a `== null` check on the (not-yet-known) new WAF ACL's ARN - see variables.tf.
  count        = var.attach_waf ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}
