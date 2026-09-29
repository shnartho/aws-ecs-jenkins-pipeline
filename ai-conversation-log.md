# AI-Assisted Engineering Decision Log

Chronological record of the requirements, decisions, tradeoffs, implementation changes, failures,
and validation evidence produced with GitHub Copilot in VS Code. Repetitive command-by-command
dialogue is condensed; decisions and material outcomes are retained.

---

## Turn 1 - User

> # Cloud Engineering Challenge Implementation Prompt
> You are acting the Most Senior Cloud Engineer helping me implement the cloud engineering
> challenge described in `task.md`.
>
> ## 1. Read the requirements first
> Before writing or modifying any code, read the complete `task.md` file. Treat `task.md` as the
> source of truth for the assignment. Extract and understand: (1) Required AWS services, (2)
> Required AWS region, (3) VPC and subnet requirements, (4) VPC peering requirements, (5) ECS and
> EC2 requirements, (6) Application deployment requirements, (7) Jenkins deployment requirements,
> (8) ALB requirements, (9) Route53 requirements, (10) CloudWatch requirements, (11) SNS
> requirements, (12) S3 logging requirements, (13) Security requirements, (14) Cost constraints,
> (15) Terraform requirements, (16) CI/CD requirements, (17) Script requirements, (18) Exactly
> three deliberate flaws, (19) Pre commit requirements, (20) AI interaction log requirements, (21)
> Documentation and decision justification requirements. Do not start implementation until you
> understand the complete requirement set.
>
> ## 2. First produce an implementation plan ... [full prompt continued with sections 2-14
> covering: implementation plan structure (architecture/networking/ECS/Terraform/CI-CD/
> observability/security/cost/testing), "do not over-engineer" guidance, Terraform design
> requirements, security-first requirements, "exactly three deliberate flaws" specification with
> required documentation format, testing/verification strategy, "AI should challenge my decisions"
> instruction, "do not hide assumptions" instruction, documentation quality requirements for
> README.md, AI interaction log requirements for ai-conversation-log.md, a 25-step implementation
> workflow, and a final requirement-by-requirement audit table format]
>
> Start by reading `task.md` and then give me: 1. A requirements summary, 2. A proposed
> architecture, 3. The repository structure, 4. The key architectural decisions and tradeoffs, 5.
> Any ambiguities or risks you identify. Do not write the implementation yet.

## Turn 1 - Assistant (summary of full response; see repository history for the verbatim message)

Read `task.md` in full. Produced:

- A **requirements summary table** covering all 17 requirement areas (services, region, VPC/subnet
  layout, compute, app/Jenkins deployment, ALBs, monitoring, logging, security, cost, Terraform
  standards, CI/CD, script, flaws, pre-commit, AI log, docs).
- A **proposed architecture** (Mermaid diagram): two peered VPCs (10.40.0.0/16 app,
  10.41.0.0/16 Jenkins), each with public ALB + private ECS-on-EC2 cluster, NAT Gateway, S3
  logging bucket, ECR, CloudWatch/SNS, Route53 health checks.
- A **proposed repository structure**: `docker/app/Dockerfile`, `jenkins/Jenkinsfile`,
  `scripts/verify_health.sh`, `terraform/modules/{ecs-service,public-alb}`,
  `terraform/envs/eu-central-1/*.tf`, pre-commit/detect-secrets configs, README, AI log.
- A **decisions & tradeoffs table** (compute choice, Jenkins build strategy, geo-restriction
  mechanism, NAT topology, instance access method, module reuse strategy, secrets handling).
- **Ambiguities/risks flagged**: domain/TLS certificate is a hard external prerequisite; Security
  Groups cannot literally do country-based geo-restriction (task wording is imprecise, WAF is the
  correct tool); the "2 free-tier t3.micro per cluster x 2 clusters" claim exceeds actual AWS
  free-tier hour allowances; Jenkins building Docker images from inside an ECS-on-EC2 container
  requires Docker socket access (docker-outside-of-docker); VPC peering has no strict functional
  need given Jenkins deploys via public AWS APIs, but is implemented anyway since the task
  explicitly requires it; Transcrypt's "encrypt sensitive credentials" requirement is in tension
  with "never hardcode secrets" and best practice (IAM roles instead of static creds); and three
  candidate flaws were proposed for approval (Terraform CPU over-allocation, Jenkins verbose S3
  logging on every run, script redundant health-check retry).

Explicitly did not write any implementation files, per the instruction; asked for confirmation on
a real domain (or a placeholder) and on the three proposed flaws before proceeding.

---

## Turn 2 - User

> The requirements summary and proposed architecture look broadly correct.
>
> Before implementing anything, make the following adjustments:
>
> 1. Keep the overall architecture, but do not start scaffolding or modifying files yet.
> 2. Keep exactly these three intentional flaws:
> - Terraform: intentionally over-allocate the application ECS task CPU from the required 256
>   units to 1024 units. Add a clear `# FLAW:` comment explaining the unnecessary capacity/cost
>   impact.
> - Jenkins: intentionally persist verbose Docker build/push logs to S3 on every pipeline run,
>   including successful runs. Add a clear `# FLAW:` comment explaining the unnecessary S3 request/
>   storage cost.
> - Script: intentionally perform a redundant health-check request after a successful health
>   check. Add a clear `# FLAW:` comment explaining the unnecessary request/latency/noise.
> These must be non-breaking, independently fixable, and easy for a reviewer to identify.
> 3. There must be exactly three intentional flaws. Do not introduce additional deliberately
>    incorrect behavior elsewhere.
> 4. Clearly distinguish intentional flaws from architectural tradeoffs. In particular: Docker
>    socket mounting for Jenkins; single NAT Gateway per VPC; four `t3.micro` instances; lack of HA
>    for some non-production components; Transcrypt configuration without actual repository
>    secrets must be documented as architectural constraints/tradeoffs, not intentional flaws.
> 5. For Jenkins Docker builds, use the simplest architecture that satisfies the assignment. Do
>    not introduce an unnecessary build-agent fleet or additional infrastructure.
> 6. For HTTPS: Parameterize the domain and ACM certificate ARN. Do not invent a real domain. If
>    deployment requires an externally supplied domain/certificate, document that clearly as an
>    external prerequisite. Do not count this as one of the three intentional flaws.
> 7. For Jenkins Portugal restriction, use AWS WAF geo-match for Portugal rather than pretending
>    Security Groups can perform country-based filtering. Document why this is necessary.
> 8. For cost, investigate whether VPC endpoints can reasonably replace some NAT traffic, but do
>    not over-engineer the solution. The assignment is a take-home exercise, not a production
>    platform.
> 9. Before writing code, produce the following for my approval: final architecture, network
>    diagram, repository tree, Terraform module boundaries, AWS resource list, dependency/order of
>    deployment, Jenkins pipeline stages, security model, monitoring/logging model, exact locations
>    of the three intentional flaws, testing strategy, cost considerations, assumptions/external
>    prerequisites, list of requirements that are ambiguous or potentially contradictory.
> 10. Do not silently make architectural decisions where the task specification is ambiguous. Flag
>     them and explain the available options.
> 11. Do not optimize for making the implementation look sophisticated. Optimize for: satisfying
>     every requirement, simple understandable Terraform, clear security boundaries,
>     reproducibility, easy peer review, minimal unnecessary infrastructure, exactly three
>     intentional flaws.
> 1. After producing the plan, stop and wait for my approval before creating or modifying
>    implementation files.

## Turn 2 - Assistant (summary; see repository history for the verbatim message)

Produced a detailed, section-by-section pre-implementation plan (still no files created):

1. **Final architecture** narrative confirming the two-VPC peered design.
2. **Network diagram** (Mermaid) showing both VPCs, NAT/S3-endpoint placement, peering, ECR/S3/
   CloudWatch/SNS/Route53 integration points.
3. **Repository tree**, refined from Turn 1 to include `.checkov.yaml`/`.tflint.hcl` and the final
   module names.
4. **Terraform module boundaries**: `modules/ecs-service` (cluster/capacity provider/ASG/task def/
   service/IAM) and `modules/public-alb` (ALB/listener/target group/SG/optional WAF association),
   both reused unmodified for app and Jenkins via variables only.
5. **AWS resource list** grouped by networking/compute/load-balancing/registry/storage/IAM/
   observability.
6. **Dependency/deployment order** (13 steps, providers through Route53/CloudWatch/SNS, noting the
   image push is a day-2 operation, not a `terraform apply` dependency).
7. **Jenkins pipeline stages**: checkout, build, push, deploy, verify, post (log archive + SNS on
   success/failure).
8. **Security model**: 443-only inbound, SSM-only instance access, WAFv2 geo-match (not SGs) for
   Jenkins, least-privilege IAM including the two AWS actions that cannot be resource-scoped, no
   committed secrets, encrypted/private S3 logging bucket.
9. **Monitoring/logging model**: ALB access logs to S3, ECS logs to CloudWatch, pipeline logs to
   S3 (site of the Jenkins flaw), Route53 health checks against ALB DNS names directly (no owned
   domain required), CloudWatch 5xx + billing alarms to SNS.
10. **Exact flaw locations** table (`app.tf`, `Jenkinsfile`, `verify_health.sh`), with an explicit
    list of things that must NOT be treated as flaws (DooD socket mount, single NAT, 4x t3.micro,
    lack of HA, Transcrypt without secrets).
11. **Testing strategy**: pre-commit stack, `terraform validate`/`plan` review, Docker build,
    Jenkinsfile review, script lint/trace, and the full list of post-apply live checks.
12. **Cost considerations**: t3.micro count vs free tier, single-NAT-per-VPC rationale, the
    investigated-and-rejected interface-VPC-endpoint approach (more expensive than the NAT Gateway
    at this traffic volume, so only the free S3 gateway endpoint was kept), WAF's small fixed cost
    as the correct price for real geo-restriction.
13. **Assumptions/external prerequisites**: ACM cert ARN required as an input, no owned domain
    needed for health checks, SNS email confirmation, AWS quota/billing-alerts prerequisite, PT-
    origin testing limitation, Docker-socket EC2-only constraint, Transcrypt-without-secrets
    honesty note.
14. **Ambiguous/contradictory requirements table** (7 items: SG-vs-WAF geo wording, Route53 domain
    dependency, TLS certificate source, VPC peering's unclear functional purpose, billing metrics'
    us-east-1-only availability, Jenkins task sizing vs. the 256/512 illustrative example, and the
    free-tier math) - each with the available options and a proposed default, explicitly flagged
    as pending confirmation rather than silently decided.

Ended by asking for explicit go-ahead before creating/modifying any files, per instruction.

---

## Turn 3 - User

> go ahead implement the full solution

## Turn 3 - Assistant

Implemented the full repository per the approved plan:

- `docker/app/Dockerfile` customizing `infrastructureascode/hello-world`.
- `scripts/verify_health.sh` (contains the script flaw) and a small `scripts/render_task_def.py`
  helper used by the Jenkins deploy stage.
- `jenkins/Jenkinsfile` (contains the Jenkins flaw), manually triggered, build/push/deploy/verify/
  notify stages.
- `terraform/modules/ecs-service` and `terraform/modules/public-alb` - the two reusable modules.
- `terraform/envs/eu-central-1/*.tf` - both VPCs (via `terraform-aws-modules/vpc/aws`), S3 gateway
  endpoints, VPC peering, S3 logging bucket + policy, ECR repo + lifecycle, WAFv2 geo-match ACL,
  Route53 health checks, CloudWatch alarms (including the cross-region billing alarm via a
  `aws.billing` provider alias) + two SNS topics, and `app.tf`/`jenkins.tf` instantiating the two
  modules with their respective variables (this is where the Terraform flaw - `task_cpu = 1024` -
  lives, clearly marked `# FLAW:`).
- `.pre-commit-config.yaml`, `.detect-secrets.json`, `.tflint.hcl`, `.checkov.yaml` (with
  documented, justified skip entries - not related to the three flaws), `.gitignore`, and a
  `terraform.tfvars.example` documenting the two required external inputs (`certificate_arn`,
  `alert_email`).
- Ran `terraform fmt -recursive -check` (clean) and `terraform init -backend=false` +
  `terraform validate` (passing) to confirm the configuration is syntactically and internally
  consistent before finishing.
- Wrote `README.md` covering overview, architecture, services, networking, Terraform structure,
  ECS architecture, Jenkins pipeline, security model, monitoring, cost decisions, the three flaws
  (with locations/fixes), testing, deployment/cleanup instructions, assumptions, tradeoffs, AI
  usage, a full requirement-by-requirement audit table, and the flaw-count audit.
- Wrote this file.

Validation confirmed that the implementation retained only the three approved intentional flaws
documented in `README.md` section 11.

---

## Turn 4 - Deployment Identity Boundary

Separated runtime IAM roles, which belong to the workload stack, from the deploy identity used to
run Terraform. Introduced a scoped deploy policy and documented the bootstrap dependency rather
than allowing the workload stack to grant its own deployment privileges.

---

## Turn 5 - Trust and Permission Policies

Separated the role trust policy from the deploy permissions policy after IAM Access Analyzer
identified a schema mismatch. The trust policy defines who may assume the role; the permissions
policy defines the AWS actions available after assumption.

---

## Turn 6 - IAM Role Assembly

Confirmed the role assembly order: apply the trust policy when creating the role, then attach the
permissions policy. This kept identity trust separate from authorization.

---

## Turn 7 - Initial Account Scope

Scoped the initial trust relationship to organization management account `337*********`. This was
later superseded by an explicit isolation decision: task-specific infrastructure, including the
ACM certificate for `*.goldrg.com`, would reside in the dedicated `gold-restaurant` workload
account rather than the organization management account.

---

## Turn 8 - Deployment Prerequisites

Identified the remaining dependencies: authenticated role assumption, an S3/DynamoDB remote-state
backend, and environment-specific certificate and notification inputs.

---

## Turn 9 - PassRole Hardening

Isolated `iam:PassRole` and constrained it with `iam:PassedToService` for EC2 and ECS tasks. This
resolved the Access Analyzer finding while preserving the least-privilege boundary.

---

## Turn 10 - Bootstrap Ownership Boundary

Implemented `terraform/bootstrap/` as an independent root module for the S3 state bucket,
DynamoDB lock table, deploy role, and identity resources. The workload root consumes those
capabilities but cannot modify its own deployment authority, preserving the privilege-escalation
boundary expected between a platform layer and a workload layer.

Replaced the temporary hand-written IAM documents with `aws_iam_policy_document` resources,
retaining scoped trust and `iam:PassedToService` controls. Both Terraform roots formatted and
validated successfully.

---

## Turn 11 - Workload Deployment

**Account and identity boundary.** The deployment was intentionally consolidated in workload
account `143*********` (`gold-restaurant`) to isolate the task and colocate its resources with the
account-bound ACM certificate for `*.goldrg.com`. Initial bootstrap resources in organization
management account `337*********` were retired during the planned ownership transition. IAM
Identity Center profiles made the boundary explicit: `gold-restaurant` for workload and bootstrap
operations, and `org-mgmt` only for the management provider alias.

**Backend design.** The partial `backend.hcl` approach added no value for a single fixed
environment. Backend identifiers were kept as literals in `backend.tf`, while the separately
applied bootstrap root retained ownership of the bucket, lock table, and deploy identity.
Bootstrap then applied successfully under the workload profile.

**TLS certificate.** Issued a wildcard `*.goldrg.com` ACM certificate in the workload account and
validated it through DNS without changing the separately hosted apex and `www` records.

**Plan-time determinism.** The first workload apply exposed two `count` expressions dependent on
unknown resource values. Explicit booleans (`attach_task_role_extra_policy`, `attach_waf`) moved
those decisions to plan time and removed the cyclic uncertainty.

**Workload deployment.** The next apply created the two VPCs, ECS clusters, ALBs, and supporting
S3, ECR, WAF, Route53, CloudWatch, and SNS resources in workload account `143*********`. The application
could not stabilize until its documented bootstrap image existed; after publishing `:initial`,
ECS reached 2/2 tasks with healthy targets. HTTPS and Route53 checks passed through the
certificate-compatible `app.goldrg.com` and `jenkins.goldrg.com` records. The three intentional
non-breaking flaws remained unchanged.

---

## Turn 12 - Pipeline Stabilization

**Repository and job setup.** Initialized source control with state, populated `.tfvars`, and
generated artifacts excluded. Configured a manually triggered Jenkins pipeline from SCM using
`jenkins/Jenkinsfile`. The first execution exposed three genuine runtime defects, distinct from
the protected flaws:

1. A 1024 MiB Jenkins reservation could not fit on a `t3.micro` after host overhead; the task
   reservation was reduced to 700 MiB.
2. Runtime CLI installation depended on an unreachable HTTP package path; tool downloads were
   moved to HTTPS.
3. CRLF line endings invalidated a multiline shell command; the command was made insensitive to
   line-ending conversion. Subsequent backend-free validation was isolated from the configured
   working directory to avoid mutating backend metadata.

**Persistent controller state.** Jenkins configuration disappeared on task replacement because
`/var/jenkins_home` was ephemeral. Added EFS mount targets and a dedicated security group, then
made EFS attachment an optional capability of the shared ECS module. Terraform references, not
an explicit `depends_on`, establish dependency order and avoid a module cycle.

At this stage, Docker socket access remained an explicit simplicity tradeoff from the approved
design; it was not classified as a defect or intentional flaw. Turn 15 later retired that design.
The resulting deployment preserved Jenkins state and completed its rolling replacement.

---

## Turn 13 - End-to-End Deployment

**Jenkins startup model.** ECS evaluated ALB health before Jenkins completed initialization,
causing avoidable task replacement. Added a reusable `health_check_grace_period_seconds` input
and set Jenkins to 300 seconds. The replacement stabilized and became healthy. The initial
administrator credential was handled operationally and remains `[REDACTED]` in this record.

**Pipeline configuration and IAM.** Task replacement exposed that mutable Jenkins-global
environment values were an undeclared dependency. Restored the required values from Terraform
outputs; Turn 15 later moved them into the task definition. Corrected the Jenkins task role for
`ecs:DescribeTaskDefinition`, which AWS does not support at resource scope, and added scoped SNS
publish access. IAM policy simulation verified both decisions.

**TLS verification.** The pipeline initially verified the raw ALB hostname, which does not match
the `*.goldrg.com` certificate. Changed verification to `app.goldrg.com`, preserving hostname
validation instead of weakening TLS checks, and documented the certificate-compatible DNS
requirement.

**App deployment capacity and timing.** ECS deployments repeatedly stalled with
`RESOURCE:MEMORY`. Each `t3.micro` registers about 940 MiB and can host only one 512 MiB app task;
with two desired tasks on two hosts, the default 100% minimum-healthy rolling strategy had no
spare placement capacity. Parameterized the reusable ECS module's deployment minimum and set the
app to 50%, allowing one task to be replaced at a time without changing the deliberate
`task_cpu = 1024` flaw. Added `aws ecs wait services-stable` to the Jenkins deploy stage so health
verification cannot run before the new revision settles.

The default 300-second target deregistration delay dominated rollout time. Parameterized it in the
ALB module, set the stateless app to 30 seconds, and retained the conservative default for Jenkins.
The app stabilized at 2 running / 2 desired with healthy targets and HTTP 200 health responses.

**End-to-end result.** Pipeline run `build-4` pushed an immutable image, registered `app:4`,
completed the serial ECS rollout, and preserved HTTP 200 throughout. Runtime duration was governed
by the intentionally capacity-constrained two-host cluster, target draining, and health-check
thresholds. ECS counts, ALB targets, ECR tags, S3 logs, CloudWatch logs, and SNS delivery were
verified. Exactly three documented intentional flaws remained.

---

## Turn 14 - Vendor-Neutral Agent Guidance

Made root `AGENTS.md` the canonical entry point and moved specialized workflows to
`.agents/skills/`. Two repository engineering workflows define the operating model:
`terraform-change` covers ownership, security, state, planning, and validation;
`repository-validation` covers change review, protected fixtures, executable checks, live
verification, and delivery hygiene.

`AGENTS.md` now documents instruction precedence, skill discovery, architecture boundaries,
commands, conventions, protected behaviors, and current deployment guidance. Copilot-specific
skill copies under `.github/skills/` were removed to avoid duplicated instructions drifting apart.
Conversation material remains only in this file; README contains only a link to this record.

---

## Turn 15 - Isolation and Ownership Hardening

The hardening phase removed Docker daemon access and startup-time package installation from the
long-running Jenkins controller. A pinned custom controller image provides runtime tools, while a
dedicated CodeBuild project owns privileged image builds. Jenkins retains orchestration and
deployment responsibility; CodeBuild alone can push to the app repository.

Terraform now injects non-secret pipeline configuration into the Jenkins task and tracks the
latest active app task-definition revision, preventing a later plan from rolling a Jenkins release
back to Terraform's bootstrap revision. Docker socket, root-user, entrypoint, and command override
support were removed from the shared ECS module. A WAF IP set sourced from AWS's published Route53
health-checker ranges permits only `/login`, before the existing country restriction.

Validation covered both Terraform roots, Python compilation, Bash syntax, and the exact three-flaw
contract. Plans ran against workload account `143*********` and showed only the expected CodeBuild, ECR,
WAF, IAM, and Jenkins changes, with no application rollback. Apply was intentionally deferred
until the versioned controller image could be built and published. Pre-commit, Checkov, and TFLint
were unavailable locally.

---

## Turn 16 - Live Hardening Rollout

Applied bootstrap IAM and workload changes in workload account `143*********`. Published the custom
Jenkins image, deployed CodeBuild and its scoped pipeline permissions, and confirmed that the app
remained on task definition `app:4` throughout.

The non-root controller exposed root-owned data on the existing EFS volume. During an approved
maintenance window, a one-off ECS task migrated `/var/jenkins_home` to UID/GID 1000 and exited
successfully; its temporary task definition was then deregistered. Persisted plugin requirements
set the minimum compatible Jenkins core at `2.568.3`, so the image was repinned, rebuilt, and
deployed as `jenkins:9`.

Final evidence: Jenkins reached 1 running / 1 desired with a healthy target; both public HTTPS
endpoints returned HTTP 200; every Route53 observation succeeded; and the workload plan
converged with no changes. Exactly three protected `FLAW:` markers remain.

---

## Turn 17 - Local Verification Automation

Created branch `feat/local-make-workflow-automation` to make repository and live-deployment checks
repeatable without embedding operator-specific values in version control. A tracked `Makefile`
defines focused targets for live verification, Terraform initialization, static validation, and
the exact three-flaw contract. A tracked `Makefile.local.example` documents the input contract,
while ignored `Makefile.local` and `backend.hcl` files retain the real AWS account and backend
values locally.

The live verifier now requires an explicit expected account, reports each check as it runs, exits
cleanly when interrupted, and correctly interprets ECS service failures and WAF association
responses. `make validate` passed both Terraform roots, Python compilation, Bash syntax, and the
three-flaw assertion. `make verify` confirmed the deployed networking, ECS services, ALBs, HTTPS,
Route53, ECR, CodeBuild, logging, EFS, and WAF controls. The remaining failed check is a genuine
operational dependency: the regional SNS email subscription is still pending confirmation and is
intentionally not suppressed by the automation.
