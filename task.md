## Design Your “Broken”Cloud Pipeline
### Objective

Design and implement a deliberately flawed cloud deployment pipeline on AWS in the Frankfurt
(eu-central-1) region using Terraform, Jenkins and Linux/Bash/Python, with assistance from
an AI assistant (e.g., Grok). The pipeline must incorporate at least the following AWS services:
EC2, ECS, IAM, Route53, S3, CloudWatch, ECR, and SNS. Deploy the infrastructure across two
VPCs with four subnets each, minimizing costs and enforcing strict security. Both the application
and Jenkins must be deployed as ECS containers via a reusable Terraform module, with ALBs,
S3 logging, and CloudWatch alarms. Introduce exactly three subtle, clearly defined flaws—one
each, in Terraform, the pipeline, and a script—that do not impair core functionality. The code
will be shared and peer-reviewed.

### Technical Scope

Deployment: Deploy a public-facing application using a custom
infrastructureascode/hello-world container and Jenkins using
jenkins/jenkins:lts as ECS containers on AWS in eu-central-1.
ECS Configuration: Use ECS with 2 EC2 free-tier instances (e.g., t3.micro) per cluster
for container hosting.
Pipeline: Automate build/deployment with a manually triggered Jenkins pipeline running
as an ECS container, emailing results for all outcomes.
Scripting: Include Bash or Python scripting for at least one component (e.g., a flawed
health check).
AI Assistance: Leverage an AI assistant (e.g., Grok) freely, submitting the full
conversation log.

### Requirements

#### 1. Service Constraints

Utilize AWS services: EC2, ECS, IAM, Route53, S3, CloudWatch (alarms and logging),
ECR (container registry), and SNS (email notifications).
Deploy all infrastructure in the Frankfurt (eu-central-1) region.

#### 2. VPC and Networking

Application VPC: CIDR range 10.40.0.0/16, created with
terraform-aws-modules/vpc/aws.
Jenkins VPC: CIDR range 10.41.0.0/16, created with
terraform-aws-modules/vpc/aws.
Subnets: Each VPC must have 4 subnets (2 public, 2 private) configured via the module.
VPC Peering: Enable communication between 10.40.0.0/16 and 10.41.0.0/16.
Internet Access: Restrict inbound traffic to HTTPS only (port 443).

#### 3. Application and Jenkins Deployment

Terraform Module: Create a reusable module to deploy both the application and Jenkins
as ECS containers on 2 EC2 free-tier instances (e.g., t3.micro) per cluster.
Placement: Deploy ECS clusters and EC2 instances in private subnets of their respective
VPCs.
Load Balancers:
◦ Application ALB in 10.40.0.0/16: Public-facing, open to all via HTTPS.
◦ Jenkins ALB in 10.41.0.0/16: Public-facing, restricted to at least Portugal via
Security Groups and ALB listener rules or WAF.
Container Configuration:
◦ Application: 2 containers (infrastructureascode/hello-world) per cluster.
◦ Jenkins: 1 container (jenkins/jenkins:lts) per cluster.
Task Definitions: Define ECS task definitions with CPU/memory limits (e.g., 256 CPU,
512 MiB).
Monitoring:
◦ Route53 health checks for each ALB (per container documentation).
◦ CloudWatch alarms for health checks (e.g., HTTP 5xx errors > 0), notifying via SNS
(subscription confirmation required).

#### 4. Security Restrictions

Security Groups:
◦ Application ALB: Allow HTTPS inbound (port 443), open to all.
◦ Jenkins ALB: Allow HTTPS inbound (port 443), restricted to at least Portugal.
◦ Outbound: Allow all traffic.
Network ACLs: Block non-HTTPS inbound traffic, aligning with Security Groups.
Geo-Restriction: Enforce Jenkins ALB access restriction using Security Groups and
ALB listener rules or WAF.

#### 5. Cost Minimization with Alarms

Use free-tier EC2 instances (t3.micro), ALBs, and minimal S3 usage.
Set up a CloudWatch cost alarm (e.g., costs > $1/day), notifying via SNS (subscription
confirmation required).

### 6. Logging

Create an S3 bucket in eu-central-1 for ALB access logs, ECS container logs, and
pipeline logs.
Attach a bucket policy allowing log writes.

#### 7. Terraform Standards

File Splitting: Define and explain a standard (e.g., by resource type, layer, or VPC) in
comments or AI log.
Comments: Add brief explanations to every Terraform resource (e.g., // ALB for

Jenkins in public subnet).
Flaw Documentation: Clearly comment the Terraform flaw (e.g., // FLAW: ECS task
CPU over-allocated, wastes resources).
Variables: Use object types with defaults, e.g.:
variable "tags" {
type = object({
environment = optional(string, "develop")
product = optional(string, "cloud")
service = optional(string, "pipeline")
})
}
Provider: Configure the AWS provider with default_tags applying the above tags.

#### 8. Flawed Pipeline Design

Introduce exactly 3 subtle, realistic flaws (one each in Terraform, Jenkins pipeline, and
script):
◦ Must not impact core functionality.
◦ Must be explicitly commented (e.g., // FLAW: Excessive S3 logging).
◦ Examples:
▪ Terraform: Over-allocate CPU in 10.40.0.0/16 ECS task.
▪ Pipeline: Log every Docker command to S3, inflating costs.
▪ Script: Redundant health check calls.

#### 9. Complexity Level

Mid-Level: Simple flaws (e.g., verbose logging).
Senior-Level: Interlinked flaws (e.g., Terraform over-allocation with pipeline logging
bloat).

### 10. AI Usage

Use AI freely for any aspect (e.g., code generation, debugging).
Submit the full AI conversation log.

#### 11. Repository and Pre-Commit

Files:
◦ Dockerfile: Customizes infrastructureascode/hello-world.
◦ Jenkinsfile: Defines the pipeline.
◦ verify_health.sh: Health check script with a flaw.
◦ Terraform files: Per your splitting standard.
◦ .pre-commit-config.yaml: Pre-commit configuration.
Pre-Commit Hooks:
◦ pre-commit/pre-commit-hooks: Check YAML syntax, etc.
◦ antonbabenko/pre-commit-terraform: Format, validate, and lint Terraform.
◦ bridgecrewio/checkov: Security/compliance scans.


◦ Yelp/detect-secrets: Credential detection (via .detect-secrets.json).
Encryption: Use Transcrypt for sensitive credentials.

#### 12. Decision Justification

Provide a paragraph justifying design decisions based on cost, speed, and complexity
(e.g., in comments or AI log).

#### 13. Deliverables

Git repository with all code.
Full AI conversation log (text file or link).

#### 14. Constraints

Pipeline must be theoretically executable if flaws are fixed.
Enforce HTTPS-only inbound access and security rules.