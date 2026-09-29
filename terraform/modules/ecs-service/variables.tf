# Reusable ECS-on-EC2 module: cluster, capacity provider, EC2 Auto Scaling group, task definition,
# and service. Used identically by both the application (app.tf) and Jenkins (jenkins.tf) -
# their differences are expressed entirely through variables, not by forking this module.

variable "name" {
  description = "Name prefix for all resources created by this module (e.g. \"app\", \"jenkins\")."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the ECS cluster's EC2 instances are launched."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the EC2 instances are launched into."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances."
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances in the cluster (fixed-size ASG: min = max = desired)."
  type        = number
  default     = 2
}

variable "container_image" {
  description = "Container image URI (e.g. ECR repo URL:tag or a public image reference)."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Number of task copies the ECS service should run."
  type        = number
  default     = 1
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores load-balancer health failures after a task starts."
  type        = number
  default     = 0
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum percentage of desired tasks that must remain healthy during a deployment."
  type        = number
  default     = 100
}

variable "track_latest_task_definition" {
  description = "Use the latest active revision in this task-definition family, including revisions registered outside Terraform."
  type        = bool
  default     = false
}

variable "task_cpu" {
  description = "Task-level CPU units (e.g. 256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Task-level memory in MiB."
  type        = number
  default     = 512
}

variable "target_group_arn" {
  description = "ALB target group ARN this service registers its tasks with."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB fronting this service, used to scope instance ingress."
  type        = string
}

variable "task_role_extra_policy_json" {
  description = "Optional extra IAM policy JSON (from data.aws_iam_policy_document) attached to the task role. Ignored unless attach_task_role_extra_policy is true."
  type        = string
  default     = null
}

variable "attach_task_role_extra_policy" {
  description = "Whether to attach task_role_extra_policy_json to the task role. A literal bool (not inferred from the JSON itself) so `count` stays statically known at plan time."
  type        = bool
  default     = false
}

variable "efs_file_system_id" {
  description = "Optional EFS file system ID to mount into the container, so its state (e.g. Jenkins job configs/build history) survives task replacements. Null means no EFS volume - the container filesystem is otherwise ephemeral."
  type        = string
  default     = null
}

variable "efs_mount_path" {
  description = "Container path the EFS volume is mounted at. Required if efs_file_system_id is set."
  type        = string
  default     = null
}

variable "container_environment" {
  description = "Non-secret environment variables injected into the container definition."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for this service's container logs."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
