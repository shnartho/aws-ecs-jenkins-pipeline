# Current AWS-published IPv4 ranges used by Route53's external health checkers.
data "aws_ip_ranges" "route53_health_checkers" {
  services = ["ROUTE53_HEALTHCHECKS"]
}

# WAF IP set kept current from AWS's authoritative health-checker range publication.
resource "aws_wafv2_ip_set" "route53_health_checkers" {
  name               = "route53-health-checkers"
  description        = "AWS-published IPv4 ranges used by Route53 health checks."
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = data.aws_ip_ranges.route53_health_checkers.cidr_blocks

  tags = merge(local.common_tags, { Name = "route53-health-checkers" })
}

# WAFv2 Web ACL restricting the Jenkins ALB to the configured allowed countries (default: Portugal).
# Security Groups cannot match on country/geolocation - they only support CIDR blocks - so WAF's
# geo-match statement is the AWS-native tool for this requirement. The ALB's security group still
# restricts the protocol/port (443 only); WAF is what actually enforces the geo-restriction.
resource "aws_wafv2_web_acl" "jenkins_geo" {
  name        = "jenkins-geo-restriction"
  description = "Allows Jenkins ALB traffic only from the configured allowed countries."
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "allow-route53-login-health-check"
    priority = 0

    action {
      allow {}
    }

    statement {
      and_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.route53_health_checkers.arn
          }
        }

        statement {
          byte_match_statement {
            positional_constraint = "EXACTLY"
            search_string         = "/login"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "jenkins-allow-route53-health"
    }
  }

  rule {
    name     = "allow-configured-countries"
    priority = 1

    action {
      allow {}
    }

    statement {
      geo_match_statement {
        country_codes = var.jenkins_allowed_country_codes
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "jenkins-allow-geo"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "jenkins-web-acl"
  }

  tags = merge(local.common_tags, { Name = "jenkins-geo-restriction" })
}
