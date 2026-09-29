# Trust policy: only the explicitly listed principals may assume this role.
data "aws_iam_policy_document" "deploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.trusted_principal_arns
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = var.deploy_role_name
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
  tags               = var.tags
}

# Permissions policy: exactly the services the workload stacks in terraform/envs/* use. IAM
# management is scoped to the app-*/jenkins-* resource names those stacks create - not
# AdministratorAccess. iam:PassRole is further restricted to the services those roles are ever
# passed to (AWS does not allow scoping iam:GetAuthorizationToken/RegisterTaskDefinition-style
# actions below account level, so those two live under CoreInfrastructure's ecr:*/ecs:* wildcards,
# which the workload stack's own IAM policies re-narrow at the task-role level).
data "aws_iam_policy_document" "deploy_permissions" {
  statement {
    sid    = "CoreInfrastructure"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "ecs:*",
      "ecr:*",
      "codebuild:*",
      "wafv2:*",
      "route53:*",
      "cloudwatch:*",
      "logs:*",
      "sns:*",
      "s3:*",
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMForRuntimeRolesOnly"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::*:role/app-*",
      "arn:aws:iam::*:role/jenkins-*",
      "arn:aws:iam::*:policy/app-*",
      "arn:aws:iam::*:policy/jenkins-*",
      "arn:aws:iam::*:instance-profile/app-*",
      "arn:aws:iam::*:instance-profile/jenkins-*",
    ]
  }

  statement {
    sid       = "PassRoleScopedToServicesThatUseIt"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/app-*", "arn:aws:iam::*:role/jenkins-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["codebuild.amazonaws.com", "ec2.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid    = "RemoteStateLocking"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [aws_dynamodb_table.lock.arn]
  }
}

resource "aws_iam_policy" "deploy" {
  name   = "${var.deploy_role_name}-permissions"
  policy = data.aws_iam_policy_document.deploy_permissions.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}
