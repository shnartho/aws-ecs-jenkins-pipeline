#!/usr/bin/env python3
"""Verify the live AWS deployment against its expected runtime requirements."""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from collections.abc import Callable
from typing import Any


class VerificationError(RuntimeError):
    """Raised when a deployment check does not meet its expected state."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


class Verifier:
    def __init__(self, profile: str, region: str, expected_account: str, timeout: int) -> None:
        self.profile = profile
        self.region = region
        self.expected_account = expected_account
        self.timeout = timeout
        self.results: list[tuple[bool, str, str]] = []
        self.load_balancers: dict[str, dict[str, Any]] = {}

    def aws_json(self, *arguments: str, region: str | None = None) -> Any:
        command = ["aws"]
        if self.profile:
            command.extend(["--profile", self.profile])
        command.extend(
            [
                "--region",
                region or self.region,
                "--no-cli-pager",
                *arguments,
                "--output",
                "json",
            ]
        )
        try:
            completed = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=self.timeout,
            )
        except FileNotFoundError as error:
            raise VerificationError("AWS CLI is not installed or is not on PATH") from error
        except subprocess.TimeoutExpired as error:
            raise VerificationError(f"AWS CLI timed out after {self.timeout}s") from error

        if completed.returncode != 0:
            detail = completed.stderr.strip() or "AWS CLI returned a non-zero exit code"
            raise VerificationError(detail)
        return json.loads(completed.stdout or "{}")

    def check(self, name: str, function: Callable[[], str]) -> None:
        print(f"⏳ {name}...", flush=True)
        try:
            detail = function()
            self.results.append((True, name, detail))
            print(f"✅ {name}: {detail}", flush=True)
        except (VerificationError, KeyError, TypeError, ValueError, urllib.error.URLError) as error:
            self.results.append((False, name, str(error)))
            print(f"❌ {name}: {error}", flush=True)

    def check_identity(self) -> str:
        identity = self.aws_json("sts", "get-caller-identity")
        require(identity["Account"] == self.expected_account, f"wrong account: {identity['Account']}")
        require(self.region == "eu-central-1", f"wrong region: {self.region}")
        return f"account {identity['Account']}, region {self.region}"

    def check_vpc(self, name: str, cidr: str) -> str:
        response = self.aws_json(
            "ec2",
            "describe-vpcs",
            "--filters",
            f"Name=tag:Name,Values={name}",
            f"Name=cidr-block,Values={cidr}",
        )
        vpcs = response.get("Vpcs", [])
        require(len(vpcs) == 1, f"expected one {name} with CIDR {cidr}, found {len(vpcs)}")
        require(vpcs[0]["State"] == "available", f"VPC state is {vpcs[0]['State']}")
        subnets = self.aws_json(
            "ec2",
            "describe-subnets",
            "--filters",
            f"Name=vpc-id,Values={vpcs[0]['VpcId']}",
        ).get("Subnets", [])
        available = [subnet for subnet in subnets if subnet["State"] == "available"]
        require(len(available) == 4, f"expected 4 available subnets, found {len(available)}")
        return f"{cidr}, 4 subnets available"

    def check_peering(self) -> str:
        connections = self.aws_json(
            "ec2",
            "describe-vpc-peering-connections",
            "--filters",
            "Name=tag:Name,Values=app-jenkins-peering",
        ).get("VpcPeeringConnections", [])
        active = [connection for connection in connections if connection["Status"]["Code"] == "active"]
        require(len(active) == 1, f"expected one active peering connection, found {len(active)}")
        cidrs = {
            active[0]["RequesterVpcInfo"]["CidrBlock"],
            active[0]["AccepterVpcInfo"]["CidrBlock"],
        }
        require(cidrs == {"10.40.0.0/16", "10.41.0.0/16"}, f"unexpected peered CIDRs: {cidrs}")
        return "app and Jenkins VPC peering is active"

    def check_ecs(self, cluster: str, service_name: str, expected_tasks: int) -> str:
        response = self.aws_json(
            "ecs", "describe-services", "--cluster", cluster, "--services", service_name
        )
        failures = response.get("failures", [])
        require(not failures, f"service lookup failures: {failures}")
        services = response.get("services", [])
        require(len(services) == 1, f"service {service_name} was not found")
        service = services[0]
        require(service["desiredCount"] == expected_tasks, f"desired count is {service['desiredCount']}")
        require(service["runningCount"] == expected_tasks, f"running count is {service['runningCount']}")
        require(service["pendingCount"] == 0, f"pending count is {service['pendingCount']}")
        primary = next(item for item in service["deployments"] if item["status"] == "PRIMARY")
        require(primary.get("rolloutState") == "COMPLETED", "deployment is not complete")

        container_instances = self.aws_json(
            "ecs", "list-container-instances", "--cluster", cluster, "--status", "ACTIVE"
        ).get("containerInstanceArns", [])
        require(len(container_instances) == 2, f"expected 2 active EC2 hosts, found {len(container_instances)}")
        revision = service["taskDefinition"].rsplit("/", 1)[-1]
        return f"{expected_tasks}/{expected_tasks} tasks running on 2 EC2 hosts ({revision})"

    def get_load_balancer(self, name: str) -> dict[str, Any]:
        if name not in self.load_balancers:
            load_balancers = self.aws_json(
                "elbv2", "describe-load-balancers", "--names", name
            ).get("LoadBalancers", [])
            require(len(load_balancers) == 1, f"load balancer {name} was not found")
            self.load_balancers[name] = load_balancers[0]
        return self.load_balancers[name]

    def check_load_balancer(self, name: str, target_group_name: str, expected_healthy: int) -> str:
        load_balancer = self.get_load_balancer(name)
        require(load_balancer["State"]["Code"] == "active", f"ALB state is {load_balancer['State']['Code']}")
        require(load_balancer["Scheme"] == "internet-facing", "ALB is not internet-facing")

        listeners = self.aws_json(
            "elbv2", "describe-listeners", "--load-balancer-arn", load_balancer["LoadBalancerArn"]
        ).get("Listeners", [])
        require(listeners and all(item["Protocol"] == "HTTPS" and item["Port"] == 443 for item in listeners),
                "ALB has a listener other than HTTPS/443")

        groups = self.aws_json(
            "ec2", "describe-security-groups", "--group-ids", *load_balancer["SecurityGroups"]
        ).get("SecurityGroups", [])
        ingress = [permission for group in groups for permission in group.get("IpPermissions", [])]
        require(ingress, "ALB security group has no ingress rule")
        require(
            all(rule.get("IpProtocol") == "tcp" and rule.get("FromPort") == 443 and rule.get("ToPort") == 443 for rule in ingress),
            "ALB security group allows inbound traffic outside HTTPS/443",
        )

        target_groups = self.aws_json(
            "elbv2", "describe-target-groups", "--names", target_group_name
        ).get("TargetGroups", [])
        require(len(target_groups) == 1, f"target group {target_group_name} was not found")
        targets = self.aws_json(
            "elbv2",
            "describe-target-health",
            "--target-group-arn",
            target_groups[0]["TargetGroupArn"],
        ).get("TargetHealthDescriptions", [])
        healthy = [target for target in targets if target["TargetHealth"]["State"] == "healthy"]
        require(len(healthy) == expected_healthy, f"expected {expected_healthy} healthy targets, found {len(healthy)}")
        unhealthy = [target["TargetHealth"]["State"] for target in targets if target["TargetHealth"]["State"] not in {"healthy", "draining"}]
        require(not unhealthy, f"unhealthy target states: {', '.join(unhealthy)}")
        return f"HTTPS-only ALB active with {expected_healthy} healthy target(s)"

    def check_url(self, url: str) -> str:
        request = urllib.request.Request(url, headers={"User-Agent": "deployment-verifier/1.0"})
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                status = response.status
        except urllib.error.HTTPError as error:
            status = error.code
        require(status == 200, f"HTTP {status} from {url}")
        return f"HTTP 200 from {url}"

    def check_route53(self, load_balancer_name: str, expected_path: str) -> str:
        load_balancer = self.get_load_balancer(load_balancer_name)
        health_checks = self.aws_json("route53", "list-health-checks").get("HealthChecks", [])
        matches = [
            item
            for item in health_checks
            if item["HealthCheckConfig"].get("FullyQualifiedDomainName") == load_balancer["DNSName"]
            and item["HealthCheckConfig"].get("ResourcePath") == expected_path
        ]
        require(len(matches) == 1, f"expected one Route53 health check for {load_balancer_name}")
        observations = self.aws_json(
            "route53", "get-health-check-status", "--health-check-id", matches[0]["Id"]
        ).get("HealthCheckObservations", [])
        require(observations, "Route53 returned no health-check observations")
        failures = [
            item["StatusReport"]["Status"]
            for item in observations
            if not item["StatusReport"]["Status"].startswith("Success")
        ]
        require(not failures, f"{len(failures)} Route53 checker(s) report failure")
        return f"all {len(observations)} Route53 checkers report success"

    def check_registries(self) -> str:
        names = ["broken-cloud-pipeline/app", "broken-cloud-pipeline/jenkins"]
        repositories = self.aws_json("ecr", "describe-repositories", "--repository-names", *names).get(
            "repositories", []
        )
        found = {repository["repositoryName"] for repository in repositories}
        require(found == set(names), f"missing ECR repositories: {set(names) - found}")
        return "application and Jenkins repositories exist"

    def check_storage_and_build(self) -> str:
        bucket = f"broken-cloud-pipeline-logs-{self.expected_account}"
        self.aws_json("s3api", "get-bucket-encryption", "--bucket", bucket)
        public_access = self.aws_json("s3api", "get-public-access-block", "--bucket", bucket)[
            "PublicAccessBlockConfiguration"
        ]
        require(all(public_access.values()), "S3 public-access block is incomplete")
        projects = self.aws_json("codebuild", "batch-get-projects", "--names", "app-image")
        require(len(projects.get("projects", [])) == 1, "CodeBuild project app-image was not found")
        return "encrypted private log bucket and CodeBuild project exist"

    def check_monitoring(self) -> str:
        regional_names = {"app-alb-5xx", "jenkins-alb-5xx"}
        regional = self.aws_json(
            "cloudwatch", "describe-alarms", "--alarm-names", *sorted(regional_names)
        ).get("MetricAlarms", [])
        billing = self.aws_json(
            "cloudwatch", "describe-alarms", "--alarm-names", "estimated-charges-daily", region="us-east-1"
        ).get("MetricAlarms", [])
        alarms = regional + billing
        found = {alarm["AlarmName"] for alarm in alarms}
        expected = regional_names | {"estimated-charges-daily"}
        require(found == expected, f"missing alarms: {expected - found}")
        require(all(alarm.get("ActionsEnabled") for alarm in alarms), "one or more alarm actions are disabled")

        topic_regions = {
            "broken-cloud-pipeline-alerts": self.region,
            "broken-cloud-pipeline-billing-alerts": "us-east-1",
        }
        unconfirmed_topics = []
        for topic_name, topic_region in topic_regions.items():
            topics = self.aws_json("sns", "list-topics", region=topic_region).get("Topics", [])
            matches = [topic["TopicArn"] for topic in topics if topic["TopicArn"].endswith(f":{topic_name}")]
            require(len(matches) == 1, f"SNS topic {topic_name} was not found")
            subscriptions = self.aws_json(
                "sns", "list-subscriptions-by-topic", "--topic-arn", matches[0], region=topic_region
            ).get("Subscriptions", [])
            confirmed = [item for item in subscriptions if item["SubscriptionArn"] != "PendingConfirmation"]
            if not confirmed:
                unconfirmed_topics.append(f"{topic_name} ({topic_region})")
        require(not unconfirmed_topics, f"SNS topics have no confirmed subscription: {', '.join(unconfirmed_topics)}")
        return "3 alarms enabled and both SNS topics have confirmed subscriptions"

    def check_logs_and_efs(self) -> str:
        groups = self.aws_json(
            "logs",
            "describe-log-groups",
            "--log-group-name-prefix",
            "/",
        ).get("logGroups", [])
        names = {group["logGroupName"] for group in groups}
        expected = {"/ecs/app", "/ecs/jenkins", "/aws/codebuild/app-image"}
        require(expected <= names, f"missing log groups: {expected - names}")

        file_systems = self.aws_json("efs", "describe-file-systems").get("FileSystems", [])
        matches = [
            file_system
            for file_system in file_systems
            if any(tag.get("Key") == "Name" and tag.get("Value") == "jenkins-home" for tag in file_system.get("Tags", []))
        ]
        require(len(matches) == 1, "Jenkins EFS file system was not found")
        require(matches[0]["LifeCycleState"] == "available", "Jenkins EFS is not available")
        require(matches[0]["NumberOfMountTargets"] == 2, "Jenkins EFS does not have 2 mount targets")
        return "required log groups and Jenkins EFS mount targets exist"

    def check_waf(self) -> str:
        load_balancer = self.get_load_balancer("jenkins-alb")
        web_acl = self.aws_json(
            "wafv2",
            "get-web-acl-for-resource",
            "--resource-arn",
            load_balancer["LoadBalancerArn"],
        ).get("WebACL")
        require(web_acl and web_acl["Name"] == "jenkins-geo-restriction", "expected Jenkins WAF is not associated")
        geo_rules = [rule for rule in web_acl["Rules"] if rule["Name"] == "allow-configured-countries"]
        require(len(geo_rules) == 1, "Jenkins geographic allow rule was not found")
        countries = geo_rules[0]["Statement"]["GeoMatchStatement"]["CountryCodes"]
        require("PT" in countries, "Jenkins WAF does not allow Portugal")
        return "WAF is associated and permits Portugal"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default=os.getenv("AWS_PROFILE", "gold-restaurant"))
    parser.add_argument("--region", default=os.getenv("AWS_REGION", "eu-central-1"))
    parser.add_argument("--expected-account", default=os.getenv("EXPECTED_AWS_ACCOUNT_ID"))
    parser.add_argument("--app-url", default="https://app.goldrg.com/health")
    parser.add_argument("--jenkins-url", default="https://jenkins.goldrg.com/login")
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()
    if not args.expected_account:
        parser.error("set --expected-account or EXPECTED_AWS_ACCOUNT_ID")
    return args


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = parse_args()
    verifier = Verifier(args.profile, args.region, args.expected_account, args.timeout)
    checks: list[tuple[str, Callable[[], str]]] = [
        ("AWS identity", verifier.check_identity),
        ("Application VPC", lambda: verifier.check_vpc("app-vpc", "10.40.0.0/16")),
        ("Jenkins VPC", lambda: verifier.check_vpc("jenkins-vpc", "10.41.0.0/16")),
        ("VPC peering", verifier.check_peering),
        ("Application ECS", lambda: verifier.check_ecs("app-cluster", "app", 2)),
        ("Jenkins ECS", lambda: verifier.check_ecs("jenkins-cluster", "jenkins", 1)),
        ("Application ALB", lambda: verifier.check_load_balancer("app-alb", "app-tg", 2)),
        ("Jenkins ALB", lambda: verifier.check_load_balancer("jenkins-alb", "jenkins-tg", 1)),
        ("Application HTTPS", lambda: verifier.check_url(args.app_url)),
        ("Jenkins HTTPS", lambda: verifier.check_url(args.jenkins_url)),
        ("Application Route53", lambda: verifier.check_route53("app-alb", "/health")),
        ("Jenkins Route53", lambda: verifier.check_route53("jenkins-alb", "/login")),
        ("ECR", verifier.check_registries),
        ("Storage and image build", verifier.check_storage_and_build),
        ("Monitoring and notifications", verifier.check_monitoring),
        ("Logs and persistent storage", verifier.check_logs_and_efs),
        ("Jenkins geographic restriction", verifier.check_waf),
    ]

    print("Deployment verification", flush=True)
    print("=======================", flush=True)
    try:
        for name, function in checks:
            verifier.check(name, function)
    except KeyboardInterrupt:
        print("\n⚠️ Verification interrupted by user.", flush=True)
        return 130

    failures = sum(not passed for passed, _, _ in verifier.results)
    print()
    if failures:
        print(f"❌ {failures} check(s) failed. The deployment does not fully match the expected live requirements.")
        return 1

    print("✅ Everything is up and matches the expected live deployment requirements.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())