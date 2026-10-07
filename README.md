# EITS Cloud Enablement AWS EventBridge Module

EITS Terraform module for AWS EventBridge events (previously known as CloudWatch Events). This module will:

- Create EventBridge event and rules
- Create an EventBridge Scheduler schedule
- Create an group, if required
- Create multiple targets for event, if required
- Create IAM Role for event/targets, if required
- Create Event Bus, and associated policy, if required
- Enable Cloudwatch logs for a custom event bus, if required
- Enable a Dead Letter Queue for a custom event bus, if required

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> As of version 1.1.0 a check has been added to the iam module which denies access to assume created roles from services outside of the Experian AWS Organization.
> If this breaks your use case, disable this functionality by setting the variable `disable_org_check` to `true`.

Useful references within this document:
- [ Creating an EventBridge Rule ](#event-rules)
- [ Creating an EventBridge Scheduler Schedule ](#scheduled-rules)
- [ Invoking SNS Topics and Lambda ](#invoking-sns-topics-and-lambda)
- [ Creating an Event Bus ](#creating-an-event-bus)

## EITS Security & Compliance

**Last Module Review**: 2026-04-10

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-09-24 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-09-24 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-09-24 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-09-24 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## EventBridge Resource Naming

This module attempts to adhere to the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E). Event rules will be named as follows:

```
{'name_prefix' variable}-{'name' variable}-event
```

IAM Roles will be created, if required, as:

```
_{name variable}_Event
```

When `role_name` is set, that exact value is used as the full IAM role name and the EEC naming convention is skipped. The default managed policy name is:

```
_{name variable}_PutEvents
```

## Creating an EventBridge Rule

A Rule specifies what EventBridge does with the events delivered to each event bus. There are two types of rules:

- Rules that match on event data (see Event Rules below)
- Rules that run on a schedule (see Scheduled Rules below)

### Event Rules

Event Rules match incoming events based on an event pattern, see [AWS Docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/eventbridge-and-event-patterns.html). To use this module to create an Event Rule, you must supply both the `event_pattern_json` and `rule_targets` parameters, for example:

```hcl
module "event_rule" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git"

    name                = "<name of event>"
    event_pattern_json  = "<json encoded string>"

    # target map for event rules
    # the map key <target_id_key> will be used as the resource target_id and must be unique, only the `arn` key is required, the rest can be omitted if not required.
    rule_targets = {
        <target_id_key> = {
            arn        = "<arn of the target>"
            input      = "<json text passed to the target>"
            role_arn   = "<arn of an existing iam role to be used for this target>"
        }
    }

    # optional arguments, omit if not using
    description       = "<description string>"
    create_event_bus  = <true/false>
    event_bus_name    = "<either an existing event bus name, or the name of the new bus if create_event_bus is true>"
    existing_role_arn = "<"arn of the existing iam role that is used for invocation">"

    # create iam role if required, will be used for above role variables
    create_iam_role       = <true/false>
    role_trusted_services = ["<optional, additional trusted services>"]

    # add tags
    tags = {
        Environment = "<env>"
        CostString  = "<CostString>"
        AppID       = "<AppID>"
    }
}
```

### Scheduled Rules

There are two ways of setting up a schedule with this module:

- Create an EventBridge Event Rule with a schedule
- Create an EventBridge Scheduler schedule

EventBridge Scheduler is a serverless scheduler service that allows you to create, run, and manage tasks. AWS recommend that EventBridge Scheduler is used to invoke targets on a schedule, rather than an EventBridge rule.

To create an EventBridge Scheduler schedule you must supply both the `schedule_expression` and `schedule_targets` variables, for example:

```hcl
module "scheduler_schedule" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git"

    name                = "<name of event>"
    schedule_expression = "<valid schedule expression, see variable description for details>"

    # target map for schedule
    # additional config is available
    schedule_targets = {
        <target_id_key> = {
            arn   = "<arn of the target>"
            input = "<json text passed to the target>"
        }
    }

    # optional scheduler arguments
    create_schedule_group = <true/false>
    schedule_group_name   = "<name of existing or new schedule group>"
    schedule_start_date   = "<date to begin invoking target>"
    schedule_end_date     = "<date to end invoking target>"
    schedule_kms_key_arn  = "<arn of KMS key is used to encrypt data>"

    # for other arguments, see event rule example above
}
```

For the full range of target config please see `schedule_targets` in the Inputs below and reference the [scheduler_schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule#argument-reference) docs for required values.

An EventBridge Scheduler schedule is the default for this module, and will be created if `schedule_expression` is supplied. To override this behaviour and use an EventBridge rule, set `enable_scheduler` to `false`. For example:

```hcl
module "scheduled_event_rule" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git"

    name                = "<name of event>"
    schedule_expression = "<valid schedule expression, see variable description for details>"

    # use an Event Rule to schedule event, not EventBridge Scheduler
    enable_scheduler = false

    # use rule_targets as this is now an event rule, not a schedule
    rule_targets = {
        <target_id_key> = {
            arn = "<arn of the target>"
        }
    }
}
```

## Invoking SNS Topics and Lambda

In order to be able to have your Lambda function or SNS topic invoked by an EventBridge rule, you must set up the right permissions. More info [here](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-use-resource-based.html).

When using our [eits-tf-aws-sns](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-sns) module, pass the following argument:

```hcl
policy_allowed_aws_services = ["events.amazonaws.com"]
```

For Lambda functions use the [aws_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) resource to grant invoke permissions to the event rule/schedule. In addition, when using EventBridge Scheduler an [execution role](https://docs.aws.amazon.com/scheduler/latest/UserGuide/setting-up.html#setting-up-execution-role) is required. This can be created using the `create_iam_role` variable and related config, making sure to grant the role "lambda:InvokeFunction" permissions to the function. Please see the "tests" directory for an example.

## Creating an Event Bus

If you want to create a new event bus alongside an event, set `create_event_bus` to `true`, and pass the `event_bus_name` name. The event rule will be associate to this new bus.

To match a partner event source with the new event bus include the `event_bus_source_name` argument, note that `event_bus_name` will be overridden in this case as their names must match.

Note: if you are just creating an EventBridge Scheduler schedule, event bus are not required.

```hcl
module "event_with_event_bus" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git"

    name             = "<name of event>"
    create_event_bus = true

    # one of the these two arguments
    event_bus_name                = "<name of new event bus>"
    event_bus_partner_source_name = "<name of partner event source to match with, see [AWS Docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-saas.html)>"

    # for other arguments, see examples above
}
```

## Enabling logging on a managed Event Bus

When you create an event bus via the module you have the option to enable logging
to either Cloudwatch Logs, an S3 Bucket or to a Kinesis Firehose Stream. This can
be enabled via the `event_bus_log_config` variable.

```hcl
module "event_with_event_bus" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git"

    create_event_bus = true
    event_bus_name   = "<name of new event bus>"
    event_bus_log_config = {
        level                        = "TRACE" # Valid values are NONE, INFO, ERROR and TRACE. Logging is disabled if set to default of NONE
        include_detail               = "FULL" # Valid values are NONE and FULL. Defaults to NONE
        cloudwatch_logs              = true   # Default is `true`
        cloudwatch_retention_in_days = 90     # Default is `90`
        s3_logs                      = true   # Default is `false`
        s3_bucket_arn                = <ARN>  # Optional, if ommited an S3 bucket is created for logs
        s3_retention_in_days         = 90     # Default `90`. Only used if module creates the S3 bucket
        firehose_logs                = true   # Default `false`
        firehose_arn                 = <ARN>  # Required if `firehose_logs` is set to `true`
    }
    # for other arguments, see examples above
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.36.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.36.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dlq"></a> [dlq](#module\_dlq) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-sqs.git | 1.6.0 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_event_bus_logs"></a> [event\_bus\_logs](#module\_event\_bus\_logs) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs | 2.6.1 |
| <a name="module_iam_role"></a> [iam\_role](#module\_iam\_role) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam | 1.9.7 |
| <a name="module_s3_logging_bucket"></a> [s3\_logging\_bucket](#module\_s3\_logging\_bucket) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git | 2.19.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_bus.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_bus_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus_policy) | resource |
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_delivery.cwlogs_error_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.cwlogs_info_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.cwlogs_trace_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.firehose_error_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.firehose_info_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.firehose_trace_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.s3_error_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.s3_info_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery.s3_trace_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.cwlogs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_destination.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_destination.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.error_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_cloudwatch_log_delivery_source.info_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_cloudwatch_log_delivery_source.trace_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_cloudwatch_log_resource_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_iam_role_policy.event_rule_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_scheduler_schedule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_scheduler_schedule_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule_group) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudwatch_event_bus.default_bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudwatch_event_bus) | data source |
| [aws_cloudwatch_event_bus.existing_bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudwatch_event_bus) | data source |
| [aws_iam_policy_document.cwlogs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.event_bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.event_rule_combined](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.event_rule_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.event_rule_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scheduler_lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attach_policy_inline"></a> [attach\_policy\_inline](#input\_attach\_policy\_inline) | When true, attaches IAM permissions as an inline role policy instead of a standalone managed policy. Use when the environment restricts iam:CreatePolicy. | `bool` | `false` | no |
| <a name="input_create_event_bus"></a> [create\_event\_bus](#input\_create\_event\_bus) | Whether to create a new event bus, `event_bus_name` is required if this is `true` | `bool` | `false` | no |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Whether to create a new IAM role. Overrides `existing_role_arn`, automatically attaches to new Event Rule. Uses `role_trusted_entities` if supplied | `bool` | `false` | no |
| <a name="input_create_schedule_group"></a> [create\_schedule\_group](#input\_create\_schedule\_group) | Creates an EventBridge Scheduler Schedule Group, requires `schedule_group_name` to be set. Not applicable if `enable_scheduler` is `false` | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | The description of the rule or schedule | `string` | `null` | no |
| <a name="input_disable_org_check"></a> [disable\_org\_check](#input\_disable\_org\_check) | Set this to true to remove the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role | `bool` | `false` | no |
| <a name="input_enable_scheduler"></a> [enable\_scheduler](#input\_enable\_scheduler) | Creates an EventBridge Scheduler schedule if `schedule_expression` is populated. AWS recommend that EventBridge Scheduler is used rather than a rule. To override this and use an EventBridge rule, set this to `false` | `bool` | `true` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | The same functionality as `state`, kept for backwards compatibility. This variable may be depreciated in future releases | `bool` | `null` | no |
| <a name="input_event_bus_allowed_principals"></a> [event\_bus\_allowed\_principals](#input\_event\_bus\_allowed\_principals) | Additional allowed principal ARNs for event bus policy. Only applicable if `create_event_bus` is `true` | `list(string)` | `[]` | no |
| <a name="input_event_bus_create_dead_letter_queue"></a> [event\_bus\_create\_dead\_letter\_queue](#input\_event\_bus\_create\_dead\_letter\_queue) | Creates an SQS queue to use as the DLQ target for the custom event bus. Only applicable if `create_event_bus` is `true` | `bool` | `false` | no |
| <a name="input_event_bus_dead_letter_queue_arn"></a> [event\_bus\_dead\_letter\_queue\_arn](#input\_event\_bus\_dead\_letter\_queue\_arn) | The ARN of the SQS dead-letter queue to use for the custom event bus. Only applicable if `create_event_bus` is `true`. If provided, this will override the create\_dead\_letter\_queue variable | `string` | `null` | no |
| <a name="input_event_bus_description"></a> [event\_bus\_description](#input\_event\_bus\_description) | The description of the event bus associated with this rule. If omitted this will be null. | `string` | `null` | no |
| <a name="input_event_bus_kms_key_identifier"></a> [event\_bus\_kms\_key\_identifier](#input\_event\_bus\_kms\_key\_identifier) | The ARN of the KMS key to use for encryption on custom event buses. Only applicable if `create_event_bus` is `true` | `string` | `null` | no |
| <a name="input_event_bus_log_config"></a> [event\_bus\_log\_config](#input\_event\_bus\_log\_config) | The log config for the custom event bus. Only applicable if `create_event_bus` is `true`. Valid values for level are `NONE`, `ERROR`, `INFO`, and `TRACE`. Valid values for include\_detail are `NONE` and `FULL`. Default retention of logs is 90 days | <pre>object({<br/>    level                        = optional(string, "NONE")<br/>    include_detail               = optional(string, "NONE")<br/>    cloudwatch_logs              = optional(bool, true)<br/>    cloudwatch_retention_in_days = optional(number, 90)<br/>    s3_logs                      = optional(bool, false)<br/>    s3_bucket_arn                = optional(string, null)<br/>    s3_retention_in_days         = optional(number, 90)<br/>    firehose_logs                = optional(bool, false)<br/>    firehose_arn                 = optional(string, null)<br/>  })</pre> | `{}` | no |
| <a name="input_event_bus_name"></a> [event\_bus\_name](#input\_event\_bus\_name) | The name or ARN of the event bus to associate with this rule. If you omit this, the default event bus is used. Also used to name a new event bus when `create_event_bus` is `true` | `string` | `null` | no |
| <a name="input_event_bus_partner_source_name"></a> [event\_bus\_partner\_source\_name](#input\_event\_bus\_partner\_source\_name) | The partner event source name that the new event bus will be matched with. Applicable only if `create_event_bus` is `true`. Will override `event_bus_name` as they must match. See [AWS Docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-saas.html) for details | `string` | `null` | no |
| <a name="input_event_pattern_json"></a> [event\_pattern\_json](#input\_event\_pattern\_json) | Creates an EventBridge rule. The event pattern described a JSON object. At least one of `schedule_expression` or `event_pattern_json` is required. See [AWS Docs](https://docs.aws.amazon.com/eventbridge/latest/userguide/eventbridge-and-event-patterns.html) for details | `string` | `null` | no |
| <a name="input_existing_role_arn"></a> [existing\_role\_arn](#input\_existing\_role\_arn) | The ARN of an existing IAM role to use for target invocation on both Event Rules and Scheduler schedules. Not applicable if `create_iam_role` is `true`. For Scheduler schedules, this is used as the default `role_arn` when none is specified per target | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the Event Rule or schedule. Must be provided if you are not just creating an event bus. The actual resource name will be created as `{name_prefix}-{name}-event` in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E). If `create_iam_role` is `true` and `role_name` is not set, this name is also used for the default IAM role naming | `string` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Used to prefix all created resources. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E) | `string` | `null` | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the created IAM role. Only applicable if `create_iam_role` is `true` | `string` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Optional custom IAM role name. When set, used as the full role name (EEC naming is skipped). When `null`, the default `_{name}_Event` convention is used. Only applicable if `create_iam_role` is `true` | `string` | `null` | no |
| <a name="input_role_policy_documents"></a> [role\_policy\_documents](#input\_role\_policy\_documents) | List of JSON IAM policy documents that will be merged and added to created IAM role. Only applicable if `create_iam_role` is `true` | `list(string)` | `[]` | no |
| <a name="input_role_trusted_services"></a> [role\_trusted\_services](#input\_role\_trusted\_services) | Additional trusted services type principals for assuming roles (trust relationship). Only applicable if `create_iam_role` is `true` | `list(string)` | `[]` | no |
| <a name="input_rule_targets"></a> [rule\_targets](#input\_rule\_targets) | A map of maps for each required Event Rule target. Each map will assign a new event target to the created Event Rule. Only the `arn` key is required, the rest can be omitted if not required. Only required if creating an Event Rule. See README.md for greater detail | <pre>map(object({<br/>    arn        = string<br/>    input      = optional(string)<br/>    input_path = optional(string)<br/>    role_arn   = optional(string)<br/>    input_transformer = optional(object({<br/>      input_template = string<br/>      input_paths    = map(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_schedule_action_after_completion"></a> [schedule\_action\_after\_completion](#input\_schedule\_action\_after\_completion) | Defines whether after successful invocation of the target, to delete the schedule. Valid values are `DELETE` or `NONE` (Default) | `string` | `"NONE"` | no |
| <a name="input_schedule_end_date"></a> [schedule\_end\_date](#input\_schedule\_end\_date) | The date in UTC before which the schedule can invoke its target. For example `2030-01-01T01:00:00Z`. Not applicable if `enable_scheduler` is `false` | `string` | `null` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | The scheduling expression. For example, `cron(0 20 * * ? *)` or `rate(5 minutes)`. Populating this will create an EventBridge Scheduler schedule unless `enable_scheduler` is `false`. Read more at [EventBridge Scheduler](https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html) | `string` | `null` | no |
| <a name="input_schedule_expression_timezone"></a> [schedule\_expression\_timezone](#input\_schedule\_expression\_timezone) | Timezone in which the scheduling expression is evaluated. Defaults to `UTC`. For example `Australia/Sydney`. Not applicable if `enable_scheduler` is `false` | `string` | `null` | no |
| <a name="input_schedule_group_name"></a> [schedule\_group\_name](#input\_schedule\_group\_name) | Name of the schedule group to associate with this schedule. When omitted, the `default` schedule group is used. If the group does not already exist `create_schedule_group` must be `true`. Not applicable if `enable_scheduler` is `false` | `string` | `null` | no |
| <a name="input_schedule_kms_key_arn"></a> [schedule\_kms\_key\_arn](#input\_schedule\_kms\_key\_arn) | ARN for the customer managed KMS key that EventBridge Scheduler will use to encrypt and decrypt your data. Not applicable if `enable_scheduler` is `false` | `string` | `""` | no |
| <a name="input_schedule_start_date"></a> [schedule\_start\_date](#input\_schedule\_start\_date) | The date in UTC after which the schedule can begin invoking its target. For example `2030-01-01T01:00:00Z`. Not applicable if `enable_scheduler` is `false` | `string` | `null` | no |
| <a name="input_schedule_targets"></a> [schedule\_targets](#input\_schedule\_targets) | A map of maps for each required schedule target. Configures the target of the EventBridge Scheduler schedule. Only the `arn` key is required, the rest can be omitted if not required. See README.md for greater detail. Only required if `enable_scheduler` is `true` and `schedule_expression` is set | <pre>map(object({<br/>    arn      = string<br/>    input    = optional(string)<br/>    role_arn = optional(string)<br/>    dead_letter_config = optional(object({<br/>      arn = optional(string)<br/>    }))<br/>    ecs_parameters = optional(object({<br/>      task_definition_arn     = optional(string)<br/>      enable_ecs_managed_tags = optional(bool)<br/>      enable_execute_command  = optional(bool)<br/>      group                   = optional(string)<br/>      launch_type             = optional(string)<br/>      platform_version        = optional(string)<br/>      propagate_tags          = optional(string)<br/>      reference_id            = optional(string)<br/>      tags                    = optional(map(any))<br/>      task_count              = optional(number)<br/>      capacity_provider_strategy = optional(object({<br/>        capacity_provider = optional(string)<br/>        base              = optional(number)<br/>        weight            = optional(number)<br/>      }))<br/>      network_configuration = optional(object({<br/>        subnets          = optional(set(string))<br/>        security_groups  = optional(set(string))<br/>        assign_public_ip = optional(bool)<br/>      }))<br/>      placement_constraints = optional(object({<br/>        type       = optional(string)<br/>        expression = optional(string)<br/>      }))<br/>      placement_strategy = optional(object({<br/>        type  = optional(string)<br/>        field = optional(string)<br/>      }))<br/>    }))<br/>    eventbridge_parameters = optional(object({<br/>      detail_type = optional(string)<br/>      source      = optional(string)<br/>    }))<br/>    kinesis_parameters = optional(object({<br/>      partition_key = optional(string)<br/>    }))<br/>    sagemaker_pipeline_parameters = optional(object({<br/>      pipeline_parameter = optional(object({<br/>        name  = optional(string)<br/>        value = optional(string)<br/>      }))<br/>    }))<br/>    sqs_parameters = optional(object({<br/>      message_group_id = optional(string)<br/>    }))<br/>    retry_policy = optional(object({<br/>      maximum_event_age_in_seconds = optional(number)<br/>      maximum_retry_attempts       = optional(number)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_state"></a> [state](#input\_state) | State of the rule or schedule. Valid values are `DISABLED`, `ENABLED`, and `ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS`. When `ENABLED`, the rule is enabled for all events except those delivered by CloudTrail. To also enable the rule for events delivered by CloudTrail, set to `ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS` | `string` | `"ENABLED"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags | `map(string)` | `{}` | no |
| <a name="input_targets"></a> [targets](#input\_targets) | The same functionality as `rule_targets`, kept for backwards compatibility. This variable may be depreciated in future releases | <pre>map(object({<br/>    arn        = string<br/>    input      = optional(string)<br/>    input_path = optional(string)<br/>    role_arn   = optional(string)<br/>    input_transformer = optional(object({<br/>      input_template = string<br/>      input_paths    = map(string)<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bus_arn"></a> [bus\_arn](#output\_bus\_arn) | The ARN of the event bus, if created. |
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | The ARN of the CloudWatch log group for the event bus, if created. |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | The name of the CloudWatch log group for the event bus, if created. |
| <a name="output_dead_letter_queue_arn"></a> [dead\_letter\_queue\_arn](#output\_dead\_letter\_queue\_arn) | The ARN of the dead letter queue for the event bus, if created or supplied. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The ARN of the iam role, if created. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the iam role, if created. |
| <a name="output_rule_arn"></a> [rule\_arn](#output\_rule\_arn) | The ARN of the event rule, if created. |
| <a name="output_rule_id"></a> [rule\_id](#output\_rule\_id) | The name of the event rule, if created. |
| <a name="output_s3_logging_bucket_arn"></a> [s3\_logging\_bucket\_arn](#output\_s3\_logging\_bucket\_arn) | The ARN of the S3 logging bucket for the event bus, if created. |
| <a name="output_schedule_arn"></a> [schedule\_arn](#output\_schedule\_arn) | The ARN of the schedule, if created. |
| <a name="output_schedule_id"></a> [schedule\_id](#output\_schedule\_id) | The name of the schedule, if created. |
<!-- END_TF_DOCS -->

## Metadata
```discoveryhub
summary: Terraform module for AWS EventBridge
region: Global
bu: EITS
contacts:
  technical: EITS UK&I Cloud Enablement Team eitsukicloud@experian.com
  product: 
```
