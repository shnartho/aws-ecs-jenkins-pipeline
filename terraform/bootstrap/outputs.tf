output "state_bucket_name" {
  description = "S3 bucket for Terraform remote state - use as the 'bucket' value in envs/*/backend.hcl."
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table for Terraform state locking - use as 'dynamodb_table' in envs/*/backend.hcl."
  value       = aws_dynamodb_table.lock.name
}

output "deploy_role_arn" {
  description = "IAM role ARN that workload Terraform runs (terraform/envs/*) should assume."
  value       = aws_iam_role.deploy.arn
}

output "sso_permission_set_arn" {
  description = "Identity Center permission set ARN granting access to the workload account."
  value       = aws_ssoadmin_permission_set.workload_admin.arn
}

output "sso_user_id" {
  description = "Identity Center user ID for the (manually-provisioned) deployer."
  value       = data.aws_identitystore_user.deployer.user_id
}
