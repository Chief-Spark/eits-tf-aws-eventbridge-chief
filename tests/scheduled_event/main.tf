# this is an example on using EventBridge Scheduler to send custom events to EventBridge on a schedule
# it creates the EventBridge Scheduler, EventBridge bus and rules, as well as the IAM resources required for Scheduler to interact with EventBridge and CloudWatch

# test region
provider "aws" {
  region = var.region
}

# locals
locals {
  name = "eits-tf-aws-scheduler"
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

# allow eventbridge to put logs in log group
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

# create EventBridge Scheduler to target both eventbridge and dlq
module "eventbridge_scheduler" {
  source = "./../.."

  name                = "${local.name}-schedule"
  description         = "Rate schedule to EventBridge custom bus"
  schedule_expression = "rate(5 minutes)"

  # create iam role with policy
  create_iam_role       = true
  role_policy_documents = [data.aws_iam_policy_document.scheduler_policy.json]
  role_trusted_services = ["scheduler.amazonaws.com"]

  # create schedule group
  create_schedule_group = true
  schedule_group_name   = "schedule-test"

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

