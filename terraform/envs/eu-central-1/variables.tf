# Terraform file-splitting standard for this environment: one file per resource *concern*
# (networking, IAM, logging, ECR, WAF, monitoring, per-service wiring), with cross-cutting reusable
# patterns factored into terraform/modules/*. See README.md "Terraform Structure" for the full rationale.

variable "tags" {
  description = "Common resource tags applied via the AWS provider's default_tags."
  type = object({
    environment = optional(string, "develop")
    product     = optional(string, "cloud")
    service     = optional(string, "pipeline")
  })
  default = {}
}

variable "app_vpc_cidr" {
  description = "CIDR block for the application VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "jenkins_vpc_cidr" {
  description = "CIDR block for the Jenkins VPC."
  type        = string
  default     = "10.41.0.0/16"
}

variable "azs" {
  description = "Availability zones used for subnets in both VPCs (exactly 2, to produce 2 public + 2 private subnets each)."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN used by BOTH ALBs' HTTPS listeners. External prerequisite: must be supplied by the caller (a real DNS-validated certificate, or a self-signed certificate imported into ACM). Terraform does not create or validate a certificate."
  type        = string
}

variable "domain_name" {
  description = "Optional friendly domain name. NOT required for Route53 health checks (those target the ALBs' own AWS DNS names directly). Only used to create optional alias records when route53_zone_id is also set."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Optional existing Route53 hosted zone ID for creating friendly alias records. Leave null to skip - health checks work without it."
  type        = string
  default     = null
}

variable "alert_email" {
  description = "Email address subscribed to the SNS notification topics. AWS will send a confirmation email that must be manually accepted before notifications are delivered."
  type        = string
}

variable "jenkins_allowed_country_codes" {
  description = "ISO 3166-1 alpha-2 country codes allowed to reach the Jenkins ALB via AWS WAFv2 geo-match. Security Groups cannot filter by country, so WAF is used instead."
  type        = list(string)
  default     = ["PT"]
}

variable "cost_alarm_threshold_usd" {
  description = "Estimated-charges threshold (USD) above which the daily cost alarm fires."
  type        = number
  default     = 1
}
