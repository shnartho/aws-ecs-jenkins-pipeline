# Identity Center (SSO) resources - MUST be applied against the AWS Organizations management
# account, not the workload account. Uses a distinct aliased provider so a single `terraform apply`
# can create the state bucket/deploy role in the workload account (default provider, whatever
# profile/credentials are ambient) AND manage SSO in the management account (this alias) at once.
provider "aws" {
  alias   = "management"
  region  = var.region
  profile = var.management_aws_profile

  default_tags {
    tags = var.tags
  }
}

# Looks up the already-enabled Identity Center instance (enabling the instance itself has no
# Terraform resource - it is a one-time, console-only action, done manually before this file
# can be applied).
data "aws_ssoadmin_instances" "this" {
  provider = aws.management
}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# Looked up, not created - this user was provisioned manually in the console (see README), since
# creating it required the exact management-account access this file's provider alias depends on.
data "aws_identitystore_user" "deployer" {
  provider          = aws.management
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.sso_user_name
    }
  }
}

resource "aws_ssoadmin_permission_set" "workload_admin" {
  provider         = aws.management
  name             = var.sso_permission_set_name
  instance_arn     = local.sso_instance_arn
  session_duration = var.sso_session_duration
}

# AdministratorAccess for the human deploying this exercise - the actual workload deploy role
# (deploy_role.tf) stays least-privilege regardless; this only controls the human's own access.
resource "aws_ssoadmin_managed_policy_attachment" "workload_admin" {
  provider           = aws.management
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.workload_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_account_assignment" "deployer_workload_account" {
  provider           = aws.management
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.workload_admin.arn

  principal_id   = data.aws_identitystore_user.deployer.user_id
  principal_type = "USER"

  target_id   = var.sso_target_account_id
  target_type = "AWS_ACCOUNT"
}
