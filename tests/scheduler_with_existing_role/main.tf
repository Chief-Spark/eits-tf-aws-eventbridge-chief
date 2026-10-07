# Tests that existing_role_arn is used as the default role_arn for Scheduler targets
# when no per-target role_arn is set (2.5.0)

provider "aws" {
  region = var.region
}

locals {
  name = "eits-tf-aws-eb-existing-role"
}

# create an SQS queue as the scheduler target
module "sqs_target" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sqs.git"

  name                   = "${local.name}-target"
  disable_default_alarms = true

  tags = var.tags
}

# trust policy allowing EventBridge Scheduler to assume the role
data "aws_iam_policy_document" "scheduler_trust" {
  statement {
    sid     = "AllowSchedulerAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

# permission policy allowing the role to send messages to the SQS target
data "aws_iam_policy_document" "sqs_send" {
  statement {
    sid       = "AllowSQSSend"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs_target.queue_arn]
  }
}

resource "aws_iam_role" "existing" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "existing" {
  name   = "${local.name}-policy"
  role   = aws_iam_role.existing.id
  policy = data.aws_iam_policy_document.sqs_send.json
}

# test module
# existing_role_arn is set at module level with no per-target role_arn
# the scheduler target should receive the existing_role_arn as its role_arn (2.5.0)
module "event" {
  source = "./../.."

  name                = local.name
  description         = "Test existing_role_arn used as default for Scheduler targets"
  schedule_expression = "rate(5 minutes)"

  existing_role_arn = aws_iam_role.existing.arn

  schedule_targets = {
    sqs_target = {
      arn   = module.sqs_target.queue_arn
      input = jsonencode({ "msg" : "test" })
    }
  }

  tags = var.tags
}
