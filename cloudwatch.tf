locals {
  managed_rules = { for rule in var.aws_managed_rule_groups : rule.name => rule }

  rules_with_alarm_configuration = {
    for key, value in merge(var.ip_set_rules, var.ip_rate_based_rules, var.geo_match_rules, local.managed_rules) : key
    => {
      rule_name                = key
      rule_alarm_configuration = value.alarm_configuration

      alarm_dimension = value.action == "block" ? "BlockedRequests" : "CountedRequests"
    } if value.alarm_configuration != null
  }
}

resource "aws_cloudwatch_log_group" "waf_log_group" {
  count = var.cloudwatch.enable_logging ? 1 : 0
  name  = "aws-waf-logs-${var.name}"

  retention_in_days = 14

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_dashboard" "waf_dashboard" {
  count          = var.cloudwatch.enable_logging && var.cloudwatch.enable_dashboard ? 1 : 0
  dashboard_name = var.name
  dashboard_body = templatefile("${path.module}/templates/cw_dashboard.json", {
    webacl_name           = aws_wafv2_web_acl.main.name
    webacl_log_group_name = one(aws_cloudwatch_log_group.waf_log_group[*].name)
    aws_region            = data.aws_region.current.name
  })

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_cloudwatch_metric_alarm" "cw_rule_alarms" {
  for_each = local.rules_with_alarm_configuration

  alarm_name = "${var.name}-${each.value.rule_name}-alarm"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = each.value.alarm_dimension
  namespace           = "AWS/WAFV2"

  period             = each.value.rule_alarm_configuration.observation_period
  threshold          = each.value.rule_alarm_configuration.threshold
  statistic          = "Sum"
  treat_missing_data = "notBreaching"

  dimensions = merge(
    var.scope == "REGIONAL" ? { Region = data.aws_region.current.name } : {},
    {
      Rule   = each.value.rule_name
      WebACL = aws_wafv2_web_acl.main.name
    }
  )

  alarm_actions = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []
  ok_actions    = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "allowed_requests_alarm" {
  count = var.allowed_requests_alarm_configuration != null ? 1 : 0

  alarm_name = "${var.name}-allowed-requests-alarm"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AllowedRequests"
  namespace           = "AWS/WAFV2"

  period             = var.allowed_requests_alarm_configuration.observation_period
  threshold          = var.allowed_requests_alarm_configuration.threshold
  statistic          = "Sum"
  treat_missing_data = "notBreaching"

  dimensions = merge(
    var.scope == "REGIONAL" ? { Region = data.aws_region.current.name } : {},
    {
      WebACL = aws_wafv2_web_acl.main.name
    }
  )

  alarm_actions = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []
  ok_actions    = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "blocked_requests_alarm" {
  count = var.blocked_requests_alarm_configuration != null ? 1 : 0

  alarm_name = "${var.name}-blocked-requests-alarm"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"

  period             = var.blocked_requests_alarm_configuration.observation_period
  threshold          = var.blocked_requests_alarm_configuration.threshold
  statistic          = "Sum"
  treat_missing_data = "notBreaching"

  dimensions = merge(
    var.scope == "REGIONAL" ? { Region = data.aws_region.current.name } : {},
    {
      WebACL = aws_wafv2_web_acl.main.name
    }
  )

  alarm_actions = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []
  ok_actions    = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "counted_requests_alarm" {
  count = var.counted_requests_alarm_configuration != null ? 1 : 0

  alarm_name = "${var.name}-counted-requests-alarm"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CountedRequests"
  namespace           = "AWS/WAFV2"

  period             = var.counted_requests_alarm_configuration.observation_period
  threshold          = var.counted_requests_alarm_configuration.threshold
  statistic          = "Sum"
  treat_missing_data = "notBreaching"

  dimensions = merge(
    var.scope == "REGIONAL" ? { Region = data.aws_region.current.name } : {},
    {
      WebACL = aws_wafv2_web_acl.main.name
    }
  )

  alarm_actions = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []
  ok_actions    = var.enable_cloudwatch_notifications_to_slack ? [one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)] : []

  tags = var.tags
}
