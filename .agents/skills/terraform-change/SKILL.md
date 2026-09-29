---
name: terraform-change
description: "Use when adding, modifying, reviewing, planning, or applying Terraform in this repository, including modules, IAM, networking, providers, state, and service wiring."
---

# Terraform Change

Use this workflow for any change under `terraform/`. Read [AGENTS.md](../../../AGENTS.md) and the
nearest existing implementation before editing.

## Choose the Ownership Boundary

- Put reusable app/Jenkins patterns in `terraform/modules/` and expose differences as typed inputs.
- Put environment wiring in `terraform/envs/eu-central-1/`, grouped by resource concern.
- Keep backend, deploy identity, and organization access in the independent `terraform/bootstrap/`
  root. Workload code must not grant its own deploy identity additional privileges.
- Extend an existing concern file unless the change introduces a genuinely separate concern.

## Implement Conservatively

1. Reuse the repository's modules, locals, variables, and tagging conventions.
2. Add a concise purpose comment above every Terraform resource and data source.
3. Use typed variables with safe defaults for reusable differences.
4. Use provider `default_tags`; add a merged `Name` tag where the resource supports tags.
5. Derive account, region, and resource identifiers from data sources or resource references.
6. Keep IAM least-privileged. Use `Resource = "*"` only when the AWS action does not support
   resource-level permissions, and document that limitation next to the statement.
7. Never commit credentials, private keys, state files, plans, or populated `.tfvars` files.
8. Justify every lint or security exception inline and in the tool configuration.
9. Preserve existing `FLAW:` acceptance fixtures unless the user explicitly requests changing
   the repository's acceptance contract.

## State and Apply Safety

- Confirm the active AWS identity and profile before `plan` or `apply`.
- Never initialize `-backend=false` in an already configured working directory. Use an isolated
  temporary copy when backend-free initialization is required.
- Run a full plan and review every action. Do not apply a targeted plan as a normal workflow.
- Do not overwrite a task definition currently managed by the Jenkins deployment pipeline.
- Never combine bootstrap and workload concerns in one apply.

## Validate

```bash
terraform -chdir=terraform fmt -recursive -check
terraform -chdir=terraform/envs/eu-central-1 validate
terraform -chdir=terraform/bootstrap validate
```

When credentials are available, run a full workload `terraform plan` with the intended AWS
profile. Finish with the [repository validation workflow](../repository-validation/SKILL.md).
