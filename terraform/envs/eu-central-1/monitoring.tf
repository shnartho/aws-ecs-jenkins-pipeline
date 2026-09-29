# Primary notification topic (eu-central-1) for application/Jenkins ALB alarms.
resource "aws_sns_topic" "alerts" {
  name = "broken-cloud-pipeline-alerts"
  tags = merge(local.common_tags, { Name = "alerts-topic" })
}

# Requires manual confirmation via the email link AWS sends after apply - cannot be automated.
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Billing metrics only exist in us-east-1, so the cost alarm needs its own topic in that region -
# CloudWatch alarm actions must reference an SNS topic in the same region as the alarm.
resource "aws_sns_topic" "billing_alerts" {
  provider = aws.billing
  name     = "broken-cloud-pipeline-billing-alerts"
  tags     = merge(local.common_tags, { Name = "billing-alerts-topic" })
}

resource "aws_sns_topic_subscription" "billing_alerts_email" {
  provider  = aws.billing
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarms when the application ALB's targets return any 5xx responses.
resource "aws_cloudwatch_metric_alarm" "app_5xx" {
  alarm_name          = "app-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Fires when the application ALB's targets return any 5xx responses."
  dimensions = {
    LoadBalancer = module.app_alb.alb_arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = merge(local.common_tags, { Name = "app-alb-5xx-alarm" })
}

# Alarms when the Jenkins ALB's targets return any 5xx responses.
resource "aws_cloudwatch_metric_alarm" "jenkins_5xx" {
  alarm_name          = "jenkins-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Fires when the Jenkins ALB's targets return any 5xx responses."
  dimensions = {
    LoadBalancer = module.jenkins_alb.alb_arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = merge(local.common_tags, { Name = "jenkins-alb-5xx-alarm" })
}

# Cost-control alarm: fires when estimated AWS charges exceed the configured daily threshold.
# Requires "Receive Billing Alerts" to be enabled in the account's Billing preferences (console-only
# setting, cannot be managed via Terraform) - external prerequisite, see README.
resource "aws_cloudwatch_metric_alarm" "cost" {
  provider            = aws.billing
  alarm_name          = "estimated-charges-daily"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600
  statistic           = "Maximum"
  threshold           = var.cost_alarm_threshold_usd
  alarm_description   = "Fires when estimated AWS charges exceed the configured daily threshold."
  dimensions = {
    Currency = "USD"
  }
  alarm_actions = [aws_sns_topic.billing_alerts.arn]
  tags          = merge(local.common_tags, { Name = "cost-alarm" })
}
