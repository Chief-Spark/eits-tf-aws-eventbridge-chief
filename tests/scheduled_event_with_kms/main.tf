# this is an example of using EventBridge Scheduler with a customer managed KMS key for encryption
# it creates a KMS key, EventBridge Scheduler, EventBridge bus and rules, as well as the IAM resources required

# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# locals
locals {
  name = "eits-tf-aws-scheduler-kms"
}

# kms key policy for EventBridge Scheduler
data "aws_iam_policy_document" "scheduler_kms_policy" {
  statement {
    sid    = "Allow EventBridge Scheduler to use KMS key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  prefix       = "eits-tf-aws-eventbridge-scheduler-kms"
  description  = "KMS key for EventBridge Scheduler encryption"
  policy       = data.aws_iam_policy_document.scheduler_kms_policy.json
  key_services = ["scheduler", "sqs"]
  key_users    = [data.aws_caller_identity.current.arn]

  tags = var.tags
}

# create cloudwatch log group with resource policy
module "cloudwatch_logs" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs"

  log_group_name    = "${local.name}-log-group"
  retention_in_days = 1

  resource_policy_principals = {
    Service = [
      "events.amazonaws.com",
      "delivery.logs.amazonaws.com"
    ]
  }

  tags = var.tags
}

# create an event rule and bus
module "test_rule_and_bus" {
  source = "./../.."

  name = "${local.name}-rule"

  event_pattern_json = jsonencode({
    detail-type = ["message"]
  })

  create_event_bus = true
  event_bus_name   = "${local.name}-bus"

  rule_targets = {
    eventbridge_to_loggroup = {
      arn = module.cloudwatch_logs.log_group_arn
    }
  }

  tags = var.tags
}

# create dead letter queue
module "sqs_dlq" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sqs.git"

  name                   = "${local.name}-dlq"
  disable_default_alarms = true

  tags = var.tags
}

# iam policy allowing scheduler to put events and send to DLQ
data "aws_iam_policy_document" "scheduler_policy" {
  statement {
    sid       = "AllowToPutEventsAndDLQ"
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "events:putEvents",
      "sqs:SendMessage"
    ]
  }
}

# create EventBridge Scheduler with KMS key for encryption
module "eventbridge_scheduler" {
  source = "./../.."

  name                 = "${local.name}-schedule"
  description          = "Rate schedule to EventBridge custom bus with KMS encryption"
  schedule_expression  = "rate(5 minutes)"
  schedule_kms_key_arn = module.kms_key.key_arn

  # create iam role with policy
  create_iam_role       = true
  role_policy_documents = [data.aws_iam_policy_document.scheduler_policy.json]
  role_trusted_services = ["scheduler.amazonaws.com"]

  # create schedule group
  create_schedule_group = true
  schedule_group_name   = "schedule-kms-test"

  # eventbridge target, with dlq as well
  schedule_targets = {
    eventbridge_and_dlq = {
      arn   = module.test_rule_and_bus.bus_arn
      input = jsonencode({ "msg" : "Hello!" })
      dead_letter_config = {
        arn = module.sqs_dlq.queue_arn
      }
      eventbridge_parameters = {
        detail_type = "message"
        source      = "scheduledEvents"
      }
    }
  }

  tags = var.tags
}
