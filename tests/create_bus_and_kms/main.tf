# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eventbridge_encrypt_policy" {
  statement {
    sid    = "Allow EventBridge to encrypt events"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:events:event-bus:arn"
      values   = ["arn:aws:events:${var.region}:${data.aws_caller_identity.current.account_id}:event-bus/event-bus-arn"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:events:${var.region}:${data.aws_caller_identity.current.account_id}:event-bus/event-bus-name"]
    }
  }
}

module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  prefix       = "eits-tf-aws-eventbridge-kms-source"
  description  = "KMS key event"
  policy       = data.aws_iam_policy_document.eventbridge_encrypt_policy.json
  key_services = ["events", "lambda", "logs", "s3", "sns", "sqs"]
  key_users    = [data.aws_caller_identity.current.arn]

  tags = var.tags
}

# test module
# example of creating a rule with a custom event bus
module "event" {
  source = "./../.."

  name                         = "eits-tf-aws-eventbridge-create-bus"
  description                  = "Example of creating a custom event bus"
  create_iam_role              = true
  create_event_bus             = true
  event_bus_kms_key_identifier = module.kms_key.key_arn
  schedule_kms_key_arn         = module.kms_key.key_arn
  event_bus_name               = "eits-tf-aws-eventbridge-bus"
  event_bus_description        = "test event bridge description"

  event_pattern_json = jsonencode({
    detail-type = [
      "Test"
    ]
  })

  tags = var.tags
}
