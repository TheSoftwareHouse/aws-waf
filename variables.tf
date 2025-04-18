variable "name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "scope" {
  type        = string
  description = "Valid values are REGIONAL or CLOUDFRONT"
}

variable "default_action" {
  type        = string
  default     = "allow"
  description = "Perform this action when no match is found in webACL rules"
}

variable "bad_user_agents" {
  type = list(string)
}

variable "aws_managed_rule_groups" {
  type = list(object({
    name                = string
    priority            = number
    action              = string
    vendor_name         = string
    version             = string
    excluded_rule_names = list(string)
    alarm_configuration = object({
      threshold          = number
      observation_period = number
    })
  }))
  description = <<-EOF
    List of managed rule groups to enable:
      - name - name of managed rule group, eg. AWSManagedRulesCommonRuleSet
      - priority - rule priority, WAF processes rules with lower priority first
      - action - defines what to do with matched request, can be either "count" or "block"
      - vendor_name - name of the managed rule group vendor, eg. "AWS"
      - version - version of the managed rule group, set to null to use default version
      - excluded_rule_names - rules whose actions are set to COUNT by the web ACL
      - alarm_configuration - alarm configuration for managed rule group
  EOF
}

variable "ip_set_rules" {
  type = map(object({
    priority           = number
    action             = string
    ip_address_version = string
    addresses          = list(string)
    alarm_configuration = object({
      threshold          = number
      observation_period = number
    })
  }))
  default     = {}
  description = <<-EOF
    Map of IP Set rules to allow/block specific IP addresses where the key is name of the rule:
      - priority - rule priority, WAF processes rules with lower priority first
      - action - defines what to do with matched request, can be either "count" or "block"
      - addresses - list of IP addresses (in CIDR notation) to block
      - alarm_configuration - alarm configuration for IP Set rule
  EOF
}

variable "ip_rate_based_rules" {
  type = map(object({
    priority = number
    action   = string
    limit    = number
    alarm_configuration = object({
      threshold          = number
      observation_period = number
    })
  }))
  default     = {}
  description = <<-EOF
    Map of IP Rate based rules (triggers the rule action on IPs with rates that go over a limit) where the key is name of the rule:
      - priority - rule priority, WAF processes rules with lower priority first
      - action - defines what to do with matched request, can be either "count" or "block"
      - limit - number of requests
      - addresses - list of IP addresses (in CIDR notation) to rate limit
      - country_codes - list of country codes to rate limit
      - alarm_configuration - alarm configuration for IP Set rule
  EOF
}

variable "geo_match_rules" {
  type = map(object({
    priority      = number
    action        = string
    country_codes = any
    alarm_configuration = object({
      threshold          = number
      observation_period = number
    })
  }))
  default     = {}
  description = <<-EOF
  Map of GEO Match rules where the key is name of the rule:
      - priority - rule priority, WAF processes rules with lower priority first
      - action - defines what to do with matched request, can be either "count" or "block"
      - country_codes - list of country codes to compare for a geo match
      - alarm_configuration - alarm configuration for IP Set rule
  EOF
}

variable "enable_cloudwatch_notifications_to_slack" {
  description = "Flag to enable sending CloudWatch alarm notifications to Slack."
  type        = bool
  default     = false
}

variable "cloudwatch_alarms_slack_webhook_url" {
  description = "Slack webhook URL for CloudWatch alarm notifications."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudwatch_alarms_slack_channel" {
  description = "Slack channel for CloudWatch alarm notifications."
  type        = string
  default     = ""
}

variable "cloudwatch_alarms_slack_username" {
  description = "Slack username for CloudWatch alarm notifications."
  type        = string
  default     = "WAF-Alarms"
}

variable "cloudwatch" {
  type = object({
    enable_dashboard            = bool
    enable_logging              = bool
    enable_alarms_notifications = bool
  })
  default = {
    enable_dashboard            = true
    enable_logging              = true
    enable_alarms_notifications = false
  }
  description = <<-EOF
  Configuration of cloudwatch services related to WAF like logging/alarms/dashboards
    - enable_dashboard - whether to enable cloudwatch dashboard that displays WebACL metrics
    - enable_logging - whether to enable logging. it needs to be enabled in order to enable dashboards
    - enable_alarms_notifications - whether to enable alarms notifications
  EOF
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "associatied_resources" {
  type    = list(string)
  default = []
}

variable "logging_filter" {
  type = object({
    default_behavior = string
    filters = list(object({
      behavior = string
      conditions = list(object({
        action = string
      }))
      requirement = string
    }))
  })
  default = {
    default_behavior = "DROP"
    filters = [{
      behavior = "KEEP"
      conditions = [
        { action = "BLOCK" },
        { action = "COUNT" }
      ]
      requirement = "MEETS_ANY"
    }]
  }
}

variable "regex_bad_urls" {
  type    = list(string)
  default = [".git", "wp-", ".env"]
}

variable "allowed_requests_alarm_configuration" {
  type = object({
    threshold          = number
    observation_period = number
  })
  default = null
  description = <<-EOF
  Configuration for allowed requests alarm:
    - threshold - number of allowed requests that will trigger the alarm
    - observation_period - period in seconds over which the threshold is evaluated
  EOF
}
