output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix, used as the CloudWatch metric dimension for this load balancer."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "ALB's AWS-assigned DNS name (used directly by Route53 health checks - no owned domain required)."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB's hosted zone ID, needed for optional Route53 alias records."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "Target group ARN for the ECS service to register with."
  value       = aws_lb_target_group.this.arn
}

output "security_group_id" {
  description = "ALB security group ID, used by the ECS module to scope instance ingress."
  value       = aws_security_group.alb.id
}
