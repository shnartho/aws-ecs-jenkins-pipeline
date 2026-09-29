# HTTPS health checks against each ALB's own AWS-assigned DNS name - this deliberately does NOT
# require an owned domain or Route53 hosted zone (see variables.tf domain_name/route53_zone_id).
resource "aws_route53_health_check" "app" {
  fqdn              = module.app_alb.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  request_interval  = 30
  failure_threshold = 3

  tags = merge(local.common_tags, { Name = "app-alb-health-check" })
}

resource "aws_route53_health_check" "jenkins" {
  fqdn              = module.jenkins_alb.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/login"
  request_interval  = 30
  failure_threshold = 3

  tags = merge(local.common_tags, { Name = "jenkins-alb-health-check" })
}

# Optional friendly DNS records - only created when the caller supplies an existing hosted zone.
# Not required for the health checks above; purely a convenience if a domain is available.
resource "aws_route53_record" "app" {
  count = var.route53_zone_id == null ? 0 : 1

  zone_id = var.route53_zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.app_alb.alb_dns_name
    zone_id                = module.app_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "jenkins" {
  count = var.route53_zone_id == null ? 0 : 1

  zone_id = var.route53_zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.jenkins_alb.alb_dns_name
    zone_id                = module.jenkins_alb.alb_zone_id
    evaluate_target_health = true
  }
}
