---
name: repository-validation
description: "Use before completing Terraform, Jenkins, Bash, Python, deployment, or security changes in this repository. Verifies formatting, behavior, security boundaries, protected fixtures, and delivery state."
---

# Repository Validation

Use the narrowest executable check first, then complete the applicable repository checks below.
Do not hide failures by weakening assertions, suppressing findings, or changing protected fixtures.

## Review the Change

1. Inspect `git status --short` and the focused diff. Keep unrelated user changes untouched.
2. Confirm the change stays within the owning module or resource concern.
3. Check that no credentials, state, plans, generated artifacts, or populated `.tfvars` files are
   staged or tracked.
4. Review IAM, network ingress, encryption, public access, and deletion behavior for accidental
   weakening.
5. Confirm documentation still matches architecture and operating procedures.

## Preserve Acceptance Fixtures

The repository intentionally protects three behaviors marked `FLAW:`:

- application task CPU over-allocation in `terraform/envs/eu-central-1/app.tf`;
- unconditional pipeline-log upload in `jenkins/Jenkinsfile`;
- redundant successful request in `scripts/verify_health.sh`.

Unless the user explicitly changes the acceptance contract, confirm all three remain and no new
`FLAW:` marker or unrelated defect was introduced:

```bash
rg -n "FLAW:" terraform jenkins scripts
```

## Run Applicable Checks

```bash
terraform -chdir=terraform fmt -recursive -check
terraform -chdir=terraform/envs/eu-central-1 validate
terraform -chdir=terraform/bootstrap validate
python -m py_compile scripts/render_task_def.py
python -m py_compile scripts/verify_deployment.py
bash -n scripts/verify_health.sh
git diff --check
```

When the required tools are installed, run:

```bash
pre-commit run --all-files
```

For live infrastructure changes, also verify the intended AWS account, inspect the complete plan,
check ECS desired/running counts and ALB target health, and exercise the affected HTTPS endpoint.

## Delivery

- Recheck `git status --short` before committing.
- Commit only intended source and documentation changes.
- Push only when the user requests publication.
- Report checks that passed, checks that failed, and checks that could not run.