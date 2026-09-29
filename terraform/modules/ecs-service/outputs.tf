output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS service ARN (usable in IAM resource restrictions)."
  value       = aws_ecs_service.this.id
}

output "task_role_arn" {
  description = "IAM role ARN used by the running task."
  value       = aws_iam_role.task.arn
}

output "task_execution_role_arn" {
  description = "IAM role ARN used by the ECS agent to pull images / ship logs."
  value       = aws_iam_role.task_execution.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group name for this service's container logs."
  value       = aws_cloudwatch_log_group.this.name
}

output "instance_security_group_id" {
  description = "Security group ID of the ECS EC2 instances - used to scope inbound rules on dependent resources (e.g. an EFS mount target's security group)."
  value       = aws_security_group.instances.id
}
