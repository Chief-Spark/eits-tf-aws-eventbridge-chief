locals {
  prefix = var.name_prefix != null ? var.name_prefix == "" ? "" : "${var.name_prefix}-" : "${module.eits_ce_common.prefix}-"
  name   = format("%s%s-event", local.prefix, var.name)
  tags   = merge(var.tags, module.eits_ce_common.tags)

  role_principals = !var.enable_scheduler ? ["events.amazonaws.com"] : (
    var.enable_scheduler && var.schedule_expression != null && var.event_pattern_json == null ? ["scheduler.amazonaws.com"] :
    ["events.amazonaws.com", "scheduler.amazonaws.com"]
  )

  iam_role_name   = var.role_name != null ? var.role_name : "_${var.name}_Event"
  iam_policy_name = var.role_name != null ? "${var.role_name}-PutEvents" : "_${var.name}_PutEvents"

  # Lambda ARNs from schedule_targets — used to grant lambda:InvokeFunction on the created IAM role
  scheduler_lambda_arns = var.enable_scheduler ? [for k, v in var.schedule_targets : v.arn if can(regex("arn:aws:lambda:.*function", v.arn))] : []

  # backwards compatibility variables
  rule_targets = length(var.targets) > 0 ? var.targets : var.rule_targets
  state        = var.enabled != null ? (var.enabled ? "ENABLED" : "DISABLED") : var.state
  enable_logging = var.event_bus_log_config.level != "NONE" && var.create_event_bus && anytrue([
    var.event_bus_log_config.cloudwatch_logs,
    var.event_bus_log_config.s3_logs,
    var.event_bus_log_config.firehose_logs
  ])
  enable_cwlogs = var.event_bus_log_config.cloudwatch_logs == true && local.enable_logging
  enable_s3logs = var.event_bus_log_config.s3_logs == true && local.enable_logging
  enable_fhlogs = var.event_bus_log_config.firehose_logs == true && local.enable_logging
}

module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-eventbridge"
  tags        = var.tags
}

# create event rule if we arent using the scheduler, or if we have an event pattern
resource "aws_cloudwatch_event_rule" "this" {
  count = !var.enable_scheduler || var.event_pattern_json != null ? 1 : 0

  name                = local.name
  state               = local.state
  description         = var.description
  event_bus_name      = var.create_event_bus ? aws_cloudwatch_event_bus.this[0].name : var.event_bus_name
  event_pattern       = var.event_pattern_json
  schedule_expression = var.enable_scheduler ? null : var.schedule_expression
  role_arn            = var.create_iam_role ? module.iam_role[0].role_arn : var.existing_role_arn

  tags = local.tags
}

# create targets if required
# note lambda target permissions must use aws_lambda_permission resource
# event target resource will ignore role_arn argument if it detects a lambda target
resource "aws_cloudwatch_event_target" "this" {
  for_each = !var.enable_scheduler || var.event_pattern_json != null ? local.rule_targets : {}

  rule           = aws_cloudwatch_event_rule.this[0].name
  target_id      = each.key
  arn            = each.value.arn
  event_bus_name = var.create_event_bus ? aws_cloudwatch_event_bus.this[0].name : var.event_bus_name
  input          = each.value.input
  input_path     = each.value.input_path
  role_arn       = can(regex("arn:aws:lambda:.*function", each.value.arn)) ? null : each.value.role_arn != null ? each.value.role_arn : var.create_iam_role ? module.iam_role[0].role_arn : null

  dynamic "input_transformer" {
    for_each = each.value.input_transformer != null ? [each.value.input_transformer] : []
    content {
      input_template = input_transformer.value.input_template
      input_paths    = input_transformer.value.input_paths
    }
  }
}

# create scheduler group if required
resource "aws_scheduler_schedule_group" "this" {
  count = var.create_schedule_group && var.schedule_group_name != null ? 1 : 0

  name = var.schedule_group_name
  tags = local.tags
}

# create scheduler if required
resource "aws_scheduler_schedule" "this" {
  count = var.enable_scheduler && var.schedule_expression != null ? 1 : 0

  name        = local.name
  state       = local.state
  group_name  = var.schedule_group_name
  description = var.description
  start_date  = var.schedule_start_date
  end_date    = var.schedule_end_date
  kms_key_arn = var.schedule_kms_key_arn

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_expression_timezone

  action_after_completion = var.schedule_action_after_completion

  flexible_time_window {
    mode = "OFF"
  }

  lifecycle {
    precondition {
      condition = !(
        !var.create_iam_role &&
        var.existing_role_arn == null &&
        anytrue([for k, v in var.schedule_targets : v.role_arn == null])
      )
      error_message = "EventBridge Scheduler targets require a role_arn. Provide `create_iam_role = true`, `existing_role_arn`, or a `role_arn` per schedule target."
    }
  }

  dynamic "target" {
    for_each = var.schedule_targets

    content {
      arn = target.value.arn
      # provider v6+ requires non-null at plan time; precondition above catches misconfiguration before apply
      role_arn = coalesce(
        target.value.role_arn,
        var.create_iam_role ? module.iam_role[0].role_arn : null,
        var.existing_role_arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/no-role-configured"
      )
      input = target.value.input

      dynamic "dead_letter_config" {
        for_each = target.value.dead_letter_config != null ? [target.value.dead_letter_config] : []
        content {
          arn = dead_letter_config.value.arn
        }
      }

      dynamic "ecs_parameters" {
        for_each = target.value.ecs_parameters != null ? [target.value.ecs_parameters] : []
        content {
          task_definition_arn     = ecs_parameters.value.task_definition_arn
          enable_ecs_managed_tags = ecs_parameters.value.enable_ecs_managed_tags
          enable_execute_command  = ecs_parameters.value.enable_execute_command
          group                   = ecs_parameters.value.group
          launch_type             = ecs_parameters.value.launch_type
          platform_version        = ecs_parameters.value.platform_version
          propagate_tags          = ecs_parameters.value.propagate_tags
          reference_id            = ecs_parameters.value.reference_id
          tags                    = ecs_parameters.value.tags
          task_count              = ecs_parameters.value.task_count

          dynamic "capacity_provider_strategy" {
            for_each = ecs_parameters.value.capacity_provider_strategy != null ? [ecs_parameters.value.capacity_provider_strategy] : []
            content {
              capacity_provider = capacity_provider_strategy.value.capacity_provider
              base              = capacity_provider_strategy.value.base
              weight            = capacity_provider_strategy.value.weight
            }
          }

          dynamic "network_configuration" {
            for_each = ecs_parameters.value.network_configuration != null ? [ecs_parameters.value.network_configuration] : []
            content {
              subnets          = network_configuration.value.subnets
              security_groups  = network_configuration.value.security_groups
              assign_public_ip = network_configuration.value.assign_public_ip
            }
          }

          dynamic "placement_constraints" {
            for_each = ecs_parameters.value.placement_constraints != null ? [ecs_parameters.value.placement_constraints] : []
            content {
              type       = placement_constraints.value.type
              expression = placement_constraints.value.expression
            }
          }

          dynamic "placement_strategy" {
            for_each = ecs_parameters.value.placement_strategy != null ? [ecs_parameters.value.placement_strategy] : []
            content {
              type  = placement_strategy.value.type
              field = placement_strategy.value.field
            }
          }

        }
      }

      dynamic "eventbridge_parameters" {
        for_each = target.value.eventbridge_parameters != null ? [target.value.eventbridge_parameters] : []
        content {
          detail_type = eventbridge_parameters.value.detail_type
          source      = eventbridge_parameters.value.source
        }
      }

      dynamic "kinesis_parameters" {
        for_each = target.value.kinesis_parameters != null ? [target.value.kinesis_parameters] : []
        content {
          partition_key = kinesis_parameters.value.partition_key
        }
      }

      dynamic "sagemaker_pipeline_parameters" {
        for_each = target.value.sagemaker_pipeline_parameters != null ? [target.value.sagemaker_pipeline_parameters] : []
        content {
          dynamic "pipeline_parameter" {
            for_each = sagemaker_pipeline_parameters.value.pipeline_parameter != null ? sagemaker_pipeline_parameters.value.pipeline_parameter : {}
            content {
              name  = pipeline_parameter.value.name
              value = pipeline_parameter.value.value
            }
          }
        }
      }

      dynamic "sqs_parameters" {
        for_each = target.value.sqs_parameters != null ? [target.value.sqs_parameters] : []
        content {
          message_group_id = sqs_parameters.value.message_group_id
        }
      }

      dynamic "retry_policy" {
        for_each = target.value.retry_policy != null ? [target.value.retry_policy] : []
        content {
          maximum_event_age_in_seconds = retry_policy.value.maximum_event_age_in_seconds
          maximum_retry_attempts       = retry_policy.value.maximum_retry_attempts
        }
      }

    }
  }

  depends_on = [aws_scheduler_schedule_group.this]
}

# create SQS DLQ if required
module "dlq" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sqs.git?ref=1.6.0"
  count  = var.event_bus_create_dead_letter_queue && var.event_bus_dead_letter_queue_arn == null ? 1 : 0

  name = var.event_bus_partner_source_name == null ? var.event_bus_name : var.event_bus_partner_source_name
  tags = local.tags
}

# create event bus if required
resource "aws_cloudwatch_event_bus" "this" {
  count = var.create_event_bus ? 1 : 0

  name               = var.event_bus_partner_source_name == null ? var.event_bus_name : var.event_bus_partner_source_name
  event_source_name  = var.event_bus_partner_source_name
  kms_key_identifier = var.event_bus_kms_key_identifier
  description        = var.event_bus_description

  dynamic "log_config" {
    for_each = local.enable_logging ? [var.event_bus_log_config] : []
    content {
      include_detail = log_config.value.include_detail
      level          = log_config.value.level
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.event_bus_dead_letter_queue_arn != null || var.event_bus_create_dead_letter_queue ? ["1"] : []
    content {
      arn = var.event_bus_dead_letter_queue_arn != null ? var.event_bus_dead_letter_queue_arn : module.dlq[0].queue_arn
    }
  }
  tags = local.tags
}

# get current account id as we want to provide policy access
data "aws_caller_identity" "current" {}

# event bus policy
data "aws_iam_policy_document" "event_bus" {
  count = var.create_event_bus ? 1 : 0

  statement {
    sid    = "AllowAccessToEventBus"
    effect = "Allow"

    actions = [
      "events:PutEvents",
      "events:PutRule",
      "events:PutTargets",
      "events:DeleteRule",
      "events:RemoveTargets",
      "events:DisableRule",
      "events:EnableRule",
      "events:TagResource",
      "events:UntagResource",
      "events:DescribeRule",
      "events:ListTargetsByRule",
      "events:ListTagsForResource"
    ]

    resources = [
      aws_cloudwatch_event_bus.this[0].arn
    ]

    principals {
      type        = "AWS"
      identifiers = distinct(concat([data.aws_caller_identity.current.account_id], var.event_bus_allowed_principals))
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "events:creatorAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_cloudwatch_event_bus_policy" "this" {
  count = var.create_event_bus ? 1 : 0

  policy         = data.aws_iam_policy_document.event_bus[0].json
  event_bus_name = reverse(split("/", aws_cloudwatch_event_bus.this[0].arn))[0]
}

# allow the created IAM role to invoke Lambda functions targeted by the scheduler
# count uses only known-at-plan-time variables; dynamic statement handles unknown ARNs from computed resources
data "aws_iam_policy_document" "scheduler_lambda_permissions" {
  count = var.create_iam_role && var.enable_scheduler && length(var.schedule_targets) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = length(local.scheduler_lambda_arns) > 0 ? [local.scheduler_lambda_arns] : []
    content {
      sid       = "AllowSchedulerLambdaInvoke"
      effect    = "Allow"
      actions   = ["lambda:InvokeFunction"]
      resources = statement.value
    }
  }
}

# create iam role if required
data "aws_iam_policy_document" "event_rule_trust" {
  count = var.create_iam_role ? 1 : 0

  statement {
    sid     = "EventTrustRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = distinct(concat(local.role_principals, var.role_trusted_services))
    }
  }
}

# get default event bus
data "aws_cloudwatch_event_bus" "default_bus" {
  count = var.create_iam_role ? 1 : 0

  name = "default"
}

# get custom event bus if specified
data "aws_cloudwatch_event_bus" "existing_bus" {
  count = var.create_event_bus == false && var.event_bus_name != null ? 1 : 0

  name = var.event_bus_name
}

# allow rule to use custom event bus if specified
data "aws_iam_policy_document" "event_rule_permissions" {
  count = var.create_iam_role ? 1 : 0

  statement {
    sid       = "AllowAccessToEventBus"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [var.create_event_bus ? aws_cloudwatch_event_bus.this[0].arn : var.event_bus_name != null ? data.aws_cloudwatch_event_bus.existing_bus[0].arn : data.aws_cloudwatch_event_bus.default_bus[0].arn]
  }
}

data "aws_iam_policy_document" "event_rule_combined" {
  count = var.create_iam_role ? 1 : 0

  source_policy_documents = concat(
    [data.aws_iam_policy_document.event_rule_permissions[0].json],
    length(data.aws_iam_policy_document.scheduler_lambda_permissions) > 0 ? [data.aws_iam_policy_document.scheduler_lambda_permissions[0].json] : [],
    var.role_policy_documents
  )
}

# create iam role if required
module "iam_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam?ref=1.9.7"
  count  = var.create_iam_role ? 1 : 0

  override_role_name   = var.role_name != null
  role_name            = local.iam_role_name
  role_description     = "IAM Role for event rule ${local.name}"
  policy_name          = local.iam_policy_name
  permissions_boundary = var.permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.event_rule_trust[0].json
  policy_documents     = var.attach_policy_inline ? [] : [data.aws_iam_policy_document.event_rule_combined[0].json]
  disable_org_check    = var.disable_org_check

  tags = local.tags
}

resource "aws_iam_role_policy" "event_rule_inline" {
  count = var.create_iam_role && var.attach_policy_inline ? 1 : 0

  name   = "BUInlineFor-${local.iam_policy_name}"
  role   = module.iam_role[0].role_name
  policy = data.aws_iam_policy_document.event_rule_combined[0].json
}
