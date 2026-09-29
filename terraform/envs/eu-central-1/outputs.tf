output "app_alb_dns_name" {
  description = "Application ALB DNS name (browse via https://<value>/)."
  value       = module.app_alb.alb_dns_name
}

output "jenkins_alb_dns_name" {
  description = "Jenkins ALB DNS name (browse via https://<value>/ from an allowed country)."
  value       = module.jenkins_alb.alb_dns_name
}

output "app_ecr_repository_url" {
  description = "ECR repository URL the Jenkins pipeline pushes application images to."
  value       = aws_ecr_repository.app.repository_url
}

output "jenkins_ecr_repository_url" {
  description = "ECR repository URL for the versioned Jenkins controller image."
  value       = aws_ecr_repository.jenkins.repository_url
}

output "app_codebuild_project_name" {
  description = "CodeBuild project Jenkins invokes for isolated application image builds."
  value       = aws_codebuild_project.app_image.name
}

output "logs_bucket_name" {
  description = "S3 bucket receiving ALB, ECS, and pipeline logs."
  value       = aws_s3_bucket.logs.bucket
}

output "app_ecs_cluster_name" {
  description = "Application ECS cluster name."
  value       = module.app_ecs.cluster_name
}

output "app_ecs_service_name" {
  description = "Application ECS service name (used as the Jenkins pipeline's deploy target)."
  value       = module.app_ecs.service_name
}

output "jenkins_ecs_cluster_name" {
  description = "Jenkins ECS cluster name."
  value       = module.jenkins_ecs.cluster_name
}

output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for ALB/application alarms (eu-central-1)."
  value       = aws_sns_topic.alerts.arn
}

output "sns_billing_alerts_topic_arn" {
  description = "SNS topic ARN for the daily cost alarm (us-east-1, required by AWS billing metrics)."
  value       = aws_sns_topic.billing_alerts.arn
}
