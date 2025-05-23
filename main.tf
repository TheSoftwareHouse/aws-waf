resource "aws_wafv2_ip_set" "this" {
  for_each           = var.ip_set_rules
  name               = each.key
  scope              = var.scope
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.addresses
  tags               = var.tags
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_wafv2_web_acl" "main" {
  name  = var.name
  scope = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_groups

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
          version     = rule.value.version
          dynamic "rule_action_override" {
            for_each = rule.value.excluded_rule_names
            content {
              name = rule_action_override.value

              action_to_use {
                allow {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.geo_match_rules

    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
      }

      statement {
        geo_match_statement {
          country_codes = rule.value.country_codes
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.ip_set_rules
    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }

        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.this[rule.key].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.ip_rate_based_rules
    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "${var.service_name}-bad-user-agents"
    priority = 12

    action {
      block {}
    }

    statement {
      or_statement {
        dynamic "statement" {
          for_each = var.bad_user_agents
          content {
            byte_match_statement {
              positional_constraint = "CONTAINS"
              search_string         = statement.value
              field_to_match {
                single_header {
                  name = "user-agent"
                }
              }
              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.service_name}-bad-user-agents"
      sampled_requests_enabled   = true
    }
  }


  rule {
    name     = "${var.service_name}-url-regex"
    priority = 13
    action {
      block {}
    }
    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.this.arn

        text_transformation {
          priority = 0
          type     = "NONE"
        }

        field_to_match {
          uri_path {}
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.service_name}-url-regex"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.cloudwatch.enable_logging ? 1 : 0
  log_destination_configs = [one(aws_cloudwatch_log_group.waf_log_group[*].arn)]
  resource_arn            = aws_wafv2_web_acl.main.arn
  logging_filter {
    default_behavior = var.logging_filter.default_behavior
    dynamic "filter" {
      for_each = var.logging_filter.filters
      content {
        behavior = filter.value.behavior

        dynamic "condition" {
          for_each = filter.value.conditions
          content {
            action_condition {
              action = condition.value.action
            }
          }
        }
        requirement = filter.value.requirement
      }
    }
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  count = length(var.associatied_resources)

  resource_arn = var.associatied_resources[count.index]
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_wafv2_regex_pattern_set" "this" {
  name        = "Regex"
  description = "Most Common Bad URLs"
  scope       = var.scope

  dynamic "regular_expression" {
    for_each = var.regex_bad_urls
    content {
      regex_string = regular_expression.value
    }
  }

  tags = var.tags
}
