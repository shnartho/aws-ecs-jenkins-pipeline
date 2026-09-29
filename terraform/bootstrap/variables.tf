variable "region" {
  description = "AWS region for the state backend and deploy role."
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for the workload stacks' Terraform remote state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking (required for Terraform < 1.10, which lacks native S3 locking)."
  type        = string
  default     = "miniclip-tfstate-lock"
}

variable "deploy_role_name" {
  description = "Name of the IAM role workload Terraform runs (terraform/envs/*) assume to deploy."
  type        = string
  default     = "miniclip"
}

variable "trusted_principal_arns" {
  description = "IAM principal ARNs (specific users/roles) allowed to assume the deploy role. Name specific principals - do not trust the whole account root outside of a throwaway/demo environment."
  type        = list(string)
}

variable "management_aws_profile" {
  description = "Local AWS CLI profile name authenticated as the AWS Organizations management account - required because Identity Center admin APIs must be called from the management (or delegated administrator) account, never from the target workload account."
  type        = string
}

variable "sso_target_account_id" {
  description = "AWS account ID that the SSO user/permission set is assigned access to (the workload account, e.g. gold-restaurant)."
  type        = string
}

variable "sso_user_name" {
  description = "IAM Identity Center username (the login name shown in the access portal)."
  type        = string
}

variable "sso_user_email" {
  description = "Email address for the Identity Center user (primary email, also used for invites)."
  type        = string
}

variable "sso_user_given_name" {
  description = "Identity Center user's given (first) name."
  type        = string
}

variable "sso_user_family_name" {
  description = "Identity Center user's family (last) name."
  type        = string
}

variable "sso_permission_set_name" {
  description = "Name of the Identity Center permission set granting access to the target account."
  type        = string
  default     = "workload-admin"
}

variable "sso_session_duration" {
  description = "Max session duration for the permission set, ISO-8601 duration (shorter is safer than the 12h default)."
  type        = string
  default     = "PT4H"
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type = object({
    environment = optional(string, "platform")
    product     = optional(string, "cloud")
    service     = optional(string, "bootstrap")
  })
  default = {}
}
