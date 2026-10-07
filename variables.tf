variable "create_event_bus" {
  type        = bool
  default     = false
  description = "Whether to create a new event bus, `event_bus_name` is required if this is `true`"
}

variable "create_iam_role" {
  type        = bool
  default     = false
  description = "Whether to create a new IAM role. Overrides `existing_role_arn`, automatically attaches to new Event Rule. Uses `role_trusted_entities` if supplied"
}

variable "state" {
  type        = string
  default     = "ENABLED"
  description = "State of the rule or schedule. Valid values are `DISABLED`, `ENABLED`, and `ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS`. When `ENABLED`, the rule is enabled for all events except those delivered by CloudTrail. To also enable the rule for events delivered by CloudTrail, set to `ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS`"
}

variable "description" {
  type        = string
  default     = null
  description = "The description of the rule or schedule"
}

variable "event_bus_allowed_principals" {
  type        = list(string)
  default     = []
  description = "Additional allowed principal ARNs for event bus policy. Only applicable if `create_event_bus` is `true`"
}

variable "event_bus_dead_letter_queue_arn" {
  type        = string
  default     = null
  description = "The ARN of the SQS dead-letter queue to use for the custom event bus. Only applicable if `create_event_bus` is `true`. If provided, this will override the create_dead_letter_queue variable"
}

variable "event_bus_create_dead_letter_queue" {
  type        = bool
  default     = false
  description = "Creates an SQS queue to use as the DLQ target for the custom event bus. Only applicable if `create_event_bus` is `true`"
}

variable "event_bus_description" {
  type        = string
  default     = null
  description = "The description of the event bus associated with this rule. If omitted this will be null."
}

variable "event_bus_log_config" {
  type = object({
    level                        = optional(string, "NONE")
    include_detail               = optional(string, "NONE")
    cloudwatch_logs              = optional(bool, true)
    cloudwatch_retention_in_days = optional(number, 90)
    s3_logs                      = optional(bool, false)
    s3_bucket_arn                = optional(string, null)
    s3_retention_in_days         = optional(number, 90)
    firehose_logs                = optional(bool, false)
    firehose_arn                 = optional(string, null)
  })
  default     = {}
  description = "The log config for the custom event bus. Only applicable if `create_event_bus` is `true`. Valid values for level are `NONE`, `ERROR`, `INFO`, and `TRACE`. Valid values for include_detail are `NONE` and `FULL`. Default retention of logs is 90 days"
  validation {
    condition     = contains(["NONE", "ERROR", "INFO", "TRACE"], var.event_bus_log_config.level)
    error_message = "The event_bus_log_config.level variable must be one of 'NONE', 'ERROR', 'INFO', or 'TRACE'"
  }
  validation {
    condition     = contains(["NONE", "FULL"], var.event_bus_log_config.include_detail)
    error_message = "The event_bus_log_config.include_detail variable must be one of `NONE` or `FULL`"
  }
  validation {
    condition     = var.event_bus_log_config.firehose_logs ? var.event_bus_log_config.firehose_arn != null : true
    error_message = "If `firehose_logs` is set to true, a valid arn for `firehose_arn` must be provided"
  }
}

variable "event_bus_name" {
  type        = string
  default     = null
  description = "The name or ARN of the event bus to associate with this rule. If you omit this, the default event bus is used. Also used to name a new event bus when `create_event_bus` is `true`"

  validation {
    condition = (
      can(regex("^[/\\.\\-_A-Za-z0-9]+$", var.event_bus_name)) || var.event_bus_name == null
    )
    error_message = "The name variable must only have alphanumeric, period, underscore and hyphen characters"
  }
}

variable "event_bus_kms_key_identifier" {
  type        = string
  default     = null
  description = "The ARN of the KMS key to use for encryption on custom event buses. Only applicable if `create_event_bus` is `true`"
}

variable "event_bus_partner_source_name" {
  type        = string
  default     = null
  description = "The partner event source name that the new event bus will be matched with. Applicable only if `create_event_bus` is `true`. Will override `event_bus_name` as they must match. See [AWS Docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-saas.html) for details"
}

variable "event_pattern_json" {
  type        = string
  default     = null
  description = "Creates an EventBridge rule. The event pattern described a JSON object. At least one of `schedule_expression` or `event_pattern_json` is required. See [AWS Docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/eventbridge-and-event-patterns.html) for details"
}

variable "existing_role_arn" {
  type        = string
  default     = null
  description = "The ARN of an existing IAM role to use for target invocation on both Event Rules and Scheduler schedules. Not applicable if `create_iam_role` is `true`. For Scheduler schedules, this is used as the default `role_arn` when none is specified per target"
}

variable "role_trusted_services" {
  type        = list(string)
  default     = []
  description = "Additional trusted services type principals for assuming roles (trust relationship). Only applicable if `create_iam_role` is `true`"
}

variable "role_policy_documents" {
  type        = list(string)
  default     = []
  description = "List of JSON IAM policy documents that will be merged and added to created IAM role. Only applicable if `create_iam_role` is `true`"
}

variable "role_name" {
  type        = string
  default     = null
  description = "Optional custom IAM role name. When set, used as the full role name (EEC naming is skipped). When `null`, the default `_{name}_Event` convention is used. Only applicable if `create_iam_role` is `true`"
}

variable "permissions_boundary" {
  type        = string
  default     = null
  description = "ARN of the policy that is used to set the permissions boundary for the created IAM role. Only applicable if `create_iam_role` is `true`"
}

variable "attach_policy_inline" {
  type        = bool
  default     = false
  description = "When true, attaches IAM permissions as an inline role policy instead of a standalone managed policy. Use when the environment restricts iam:CreatePolicy."
}

variable "name" {
  type        = string
  default     = null
  description = "The name of the Event Rule or schedule. Must be provided if you are not just creating an event bus. The actual resource name will be created as `{name_prefix}-{name}-event` in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E). If `create_iam_role` is `true` and `role_name` is not set, this name is also used for the default IAM role naming"

  validation {
    condition = (
      var.name == null ? true : can(regex("^[a-zA-Z0-9-_]+$", var.name))
    )
    error_message = "The name variable must have alphanumeric, underscore and hyphen characters"
  }
}

variable "name_prefix" {
  type        = string
  default     = null
  description = "Used to prefix all created resources. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E)"
}

variable "enable_scheduler" {
  type        = bool
  default     = true
  description = "Creates an EventBridge Scheduler schedule if `schedule_expression` is populated. AWS recommend that EventBridge Scheduler is used rather than a rule. To override this and use an EventBridge rule, set this to `false`"
}

variable "schedule_expression" {
  type        = string
  default     = null
  description = "The scheduling expression. For example, `cron(0 20 * * ? *)` or `rate(5 minutes)`. Populating this will create an EventBridge Scheduler schedule unless `enable_scheduler` is `false`. Read more at [EventBridge Scheduler](https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html)"
}

variable "create_schedule_group" {
  type        = bool
  default     = false
  description = "Creates an EventBridge Scheduler Schedule Group, requires `schedule_group_name` to be set. Not applicable if `enable_scheduler` is `false`"
}

variable "schedule_action_after_completion" {
  type        = string
  default     = "NONE"
  description = "Defines whether after successful invocation of the target, to delete the schedule. Valid values are `DELETE` or `NONE` (Default)"
  validation {
    condition     = contains(["DELETE", "NONE"], var.schedule_action_after_completion)
    error_message = "The schedule_action_after_completion variable must be one of 'DELETE' or 'NONE'"
  }
}

variable "schedule_group_name" {
  type        = string
  default     = null
  description = "Name of the schedule group to associate with this schedule. When omitted, the `default` schedule group is used. If the group does not already exist `create_schedule_group` must be `true`. Not applicable if `enable_scheduler` is `false`"
}

variable "schedule_start_date" {
  type        = string
  default     = null
  description = "The date in UTC after which the schedule can begin invoking its target. For example `2030-01-01T01:00:00Z`. Not applicable if `enable_scheduler` is `false`"
}

variable "schedule_end_date" {
  type        = string
  default     = null
  description = "The date in UTC before which the schedule can invoke its target. For example `2030-01-01T01:00:00Z`. Not applicable if `enable_scheduler` is `false`"
}

variable "schedule_expression_timezone" {
  type        = string
  default     = null
  description = "Timezone in which the scheduling expression is evaluated. Defaults to `UTC`. For example `Australia/Sydney`. Not applicable if `enable_scheduler` is `false`"
}

variable "schedule_kms_key_arn" {
  type        = string
  default     = ""
  description = "ARN for the customer managed KMS key that EventBridge Scheduler will use to encrypt and decrypt your data. Not applicable if `enable_scheduler` is `false`"
}

variable "schedule_targets" {
  type = map(object({
    arn      = string
    input    = optional(string)
    role_arn = optional(string)
    dead_letter_config = optional(object({
      arn = optional(string)
    }))
    ecs_parameters = optional(object({
      task_definition_arn     = optional(string)
      enable_ecs_managed_tags = optional(bool)
      enable_execute_command  = optional(bool)
      group                   = optional(string)
      launch_type             = optional(string)
      platform_version        = optional(string)
      propagate_tags          = optional(string)
      reference_id            = optional(string)
      tags                    = optional(map(any))
      task_count              = optional(number)
      capacity_provider_strategy = optional(object({
        capacity_provider = optional(string)
        base              = optional(number)
        weight            = optional(number)
      }))
      network_configuration = optional(object({
        subnets          = optional(set(string))
        security_groups  = optional(set(string))
        assign_public_ip = optional(bool)
      }))
      placement_constraints = optional(object({
        type       = optional(string)
        expression = optional(string)
      }))
      placement_strategy = optional(object({
        type  = optional(string)
        field = optional(string)
      }))
    }))
    eventbridge_parameters = optional(object({
      detail_type = optional(string)
      source      = optional(string)
    }))
    kinesis_parameters = optional(object({
      partition_key = optional(string)
    }))
    sagemaker_pipeline_parameters = optional(object({
      pipeline_parameter = optional(object({
        name  = optional(string)
        value = optional(string)
      }))
    }))
    sqs_parameters = optional(object({
      message_group_id = optional(string)
    }))
    retry_policy = optional(object({
      maximum_event_age_in_seconds = optional(number)
      maximum_retry_attempts       = optional(number)
    }))
  }))
  default     = {}
  description = "A map of maps for each required schedule target. Configures the target of the EventBridge Scheduler schedule. Only the `arn` key is required, the rest can be omitted if not required. See README.md for greater detail. Only required if `enable_scheduler` is `true` and `schedule_expression` is set"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "rule_targets" {
  type = map(object({
    arn        = string
    input      = optional(string)
    input_path = optional(string)
    role_arn   = optional(string)
    input_transformer = optional(object({
      input_template = string
      input_paths    = map(string)
    }))
  }))
  default     = {}
  description = "A map of maps for each required Event Rule target. Each map will assign a new event target to the created Event Rule. Only the `arn` key is required, the rest can be omitted if not required. Only required if creating an Event Rule. See README.md for greater detail"
}

variable "disable_org_check" {
  type        = bool
  default     = false
  description = "Set this to true to remove the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role"
}

# deprecated variables
variable "enabled" {
  type        = bool
  default     = null
  description = "The same functionality as `state`, kept for backwards compatibility. This variable may be depreciated in future releases"
}

variable "targets" {
  type = map(object({
    arn        = string
    input      = optional(string)
    input_path = optional(string)
    role_arn   = optional(string)
    input_transformer = optional(object({
      input_template = string
      input_paths    = map(string)
    }))
  }))
  default     = {}
  description = "The same functionality as `rule_targets`, kept for backwards compatibility. This variable may be depreciated in future releases"
}
