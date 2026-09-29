# Reusable public ALB module: security group, load balancer, target group, HTTPS listener, and an
# optional WAFv2 association. Used identically for the app ALB (open to all) and the Jenkins ALB
# (WAF-restricted) - the difference is expressed via the waf_web_acl_arn/allowed_cidrs variables.

variable "name" {
  description = "Name prefix for all resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the ALB and its security group are created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the ALB is placed in (must span at least 2 AZs)."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. External prerequisite - see README."
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on port 443 at the security-group layer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "waf_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN to associate with the ALB (used for Jenkins' geo-restriction, since Security Groups cannot filter by country). Ignored unless attach_waf is true."
  type        = string
  default     = null
}

variable "attach_waf" {
  description = "Whether to associate waf_web_acl_arn with this ALB. A literal bool (not inferred from the ARN itself) so `count` stays statically known at plan time."
  type        = bool
  default     = false
}

variable "container_port" {
  description = "Port the target group forwards traffic to on ECS instances."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path used for target group health checks."
  type        = string
  default     = "/health"
}

variable "deregistration_delay_seconds" {
  description = "Seconds the target group allows existing connections to drain before deregistration."
  type        = number
  default     = 300
}

variable "logs_bucket" {
  description = "S3 bucket name that receives this ALB's access logs."
  type        = string
}

variable "logs_prefix" {
  description = "S3 key prefix for this ALB's access logs."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
