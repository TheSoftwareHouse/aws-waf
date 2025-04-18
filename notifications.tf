data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "waf_cloudwatch_notifications" {
  count = var.enable_cloudwatch_notifications_to_slack ? 1 : 0
  name  = "${var.name}-waf-cloudwatch-notifications"
  tags  = var.tags
}

data "aws_iam_policy_document" "waf_cloudwatch_notifications_policy" {
  count = var.enable_cloudwatch_notifications_to_slack ? 1 : 0

  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)
    ]

    sid = "__default_statement_ID"
  }

  statement {
    actions = [
      "SNS:Publish",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [
      one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)
    ]

    sid = "__AllowNotificationsFromCloudWatchAlarms"
  }
}

resource "aws_sns_topic_policy" "waf_cloudwatch_notifications" {
  count = var.enable_cloudwatch_notifications_to_slack ? 1 : 0
  arn   = one(aws_sns_topic.waf_cloudwatch_notifications[*].arn)
  policy = one(data.aws_iam_policy_document.waf_cloudwatch_notifications_policy[*].json)
}

module "notify_cloudwatch_alarms" {
  count = var.enable_cloudwatch_notifications_to_slack ? 1 : 0

  source  = "terraform-aws-modules/notify-slack/aws"
  version = ">= 6.0"

  sns_topic_name   = one(aws_sns_topic.waf_cloudwatch_notifications[*].name)
  create_sns_topic = false

  slack_webhook_url = var.cloudwatch_alarms_slack_webhook_url
  slack_channel     = var.cloudwatch_alarms_slack_channel
  slack_username    = var.cloudwatch_alarms_slack_username

  lambda_function_name = "${var.name}-waf-cw-notify"
  iam_role_name_prefix = "tsh"

  tags = var.tags
} 