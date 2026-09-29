# Repository Guidelines for AI Agents

This repository contains an AWS deployment for a small application and Jenkins, implemented with
Terraform, Jenkins, Bash, Python, and ECS on EC2 in `eu-central-1`. Use [README.md](README.md) for
architecture and operations, and [task.md](task.md) for acceptance requirements.

## Instruction Order

1. Follow the user's current request.
2. Follow this file for repository-wide conventions.
3. Load the relevant workflow from `.agents/skills/` before making specialized changes.
4. Follow instructions nearest to the files being changed if nested guidance is added later.

Do not duplicate instructions across agent-specific directories. `AGENTS.md` and `.agents/skills/`
are the canonical, vendor-neutral guidance for this repository.

## Available Skills

- [Terraform Change](.agents/skills/terraform-change/SKILL.md): use for Terraform resources,
  modules, IAM, networking, state boundaries, or provider changes.
- [Repository Validation](.agents/skills/repository-validation/SKILL.md): use before completing
  infrastructure, pipeline, shell, or deployment-related work.

## Architecture (see README.md for full detail)

- Two peered VPCs (`10.40.0.0/16` app, `10.41.0.0/16` Jenkins), each with a public ALB + private
  ECS-on-EC2 cluster.
- `terraform/bootstrap/` - **separate, rarely-applied** root module (local state) that creates the
  state backend (S3+DynamoDB) and the deploy IAM role/SSO identity resources. Never merge this
  layer's concerns into `terraform/envs/*` - a workload stack must never be able to grant itself
  more IAM power (privilege-escalation boundary, see `terraform/bootstrap/providers.tf`).
- `terraform/envs/eu-central-1/` - the actual workload stack, one file per resource concern.
- `terraform/modules/{ecs-service,public-alb}` - reusable modules, instantiated once for the app
  and once for Jenkins via variables only (never fork/duplicate these modules).
- `jenkins/Jenkinsfile`, `scripts/verify_health.sh`, `docker/app/Dockerfile` - the non-Terraform
  deliverables.

## Build, Validate, Test

```bash
# Format + validate any Terraform change before considering it done
terraform -chdir=terraform fmt -recursive -check
terraform -chdir=terraform/envs/eu-central-1 validate
terraform -chdir=terraform/bootstrap validate

# Lint/security (requires: pip install pre-commit, checkov, detect-secrets; tflint installed separately)
pre-commit run --all-files
```

There is no application test suite - "testing" here means the checks in
[README.md's Testing section](README.md#12-testing) (fmt/validate/lint/checkov/detect-secrets plus,
for a live account, the post-apply verification checklist).

## Conventions (do not silently deviate)

- **Every Terraform resource gets a one-line `#`/`//` comment** explaining its purpose - this is a
  stated project requirement, not optional style.
- **Tags**: use `var.tags` (object type with `optional()` defaults) + provider `default_tags`;
  merge `local.common_tags`/`var.tags` into a `Name` tag on resources that need one, don't invent a
  new tagging scheme.
- **File-splitting standard**: one file per resource concern in `envs/eu-central-1` (documented at
  the top of that directory's `variables.tf` and in README section 5). Reusable multi-resource
  patterns go in `terraform/modules/`, not duplicated per environment.
- **Checkov/tflint skips must be justified inline** (`# checkov:skip=<ID>: <reason>`) and mirrored
  in `.checkov.yaml` - never silence a finding without a one-line reason a reviewer can check.
- **No hardcoded credentials or secrets, ever** - use IAM roles/`data.aws_iam_policy_document`.
  `.detect-secrets.json` is the baseline; regenerate it (`detect-secrets scan`) if it drifts, don't
  hand-edit results into it to hide a real finding.

## Exactly Three Intentional Flaws - Do Not "Fix" Them

This repo intentionally contains **exactly three** flaws, each tagged `# FLAW:` and documented in
[README.md section 11](README.md#11-the-three-deliberate-flaws):

1. Terraform: `terraform/envs/eu-central-1/app.tf` - app task `cpu = 1024` instead of `256`.
2. Jenkins: `jenkins/Jenkinsfile` - `post.always` uploads verbose logs to S3 on every run.
3. Script: `scripts/verify_health.sh` - redundant health check after success.

**Do not "fix" these unless explicitly asked to** - they are protected acceptance fixtures. Do not
introduce another flaw or weaken security/functionality while making unrelated changes. Run the
[repository validation workflow](.agents/skills/repository-validation/SKILL.md) before completing
non-trivial work.

## Deployment State (for resuming work)

- AWS accounts in play: workload = `gold-restaurant (143*********)`, org management =
  `337*********`. Never deploy workload resources into the management account.
- Local AWS CLI profiles: `gold-restaurant` (workload, used for `terraform/envs/*` and most of
  `terraform/bootstrap`) and `org-mgmt` (management account, used only by the `aws.management`
  provider alias in `terraform/bootstrap/sso.tf` for Identity Center resources).
- `terraform/bootstrap` and `terraform/envs/eu-central-1` have both been applied. Treat live state
  as mutable operational data: inspect AWS and run `terraform plan` rather than relying on task
  revision numbers recorded in documentation.
- Jenkins deploys new application task-definition revisions. Never run `terraform apply` while a
  Jenkins deployment is active; review the plan carefully for task-definition rollback first.
