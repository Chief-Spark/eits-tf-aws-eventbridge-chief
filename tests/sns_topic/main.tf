# test region
provider "aws" {
  region = var.region
}

# create sns topic
module "sns" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git"

  name                        = "eits-tf-aws-eventbridge-sns"
  policy_allowed_aws_services = ["events.amazonaws.com"]
  disable_default_alarms      = true

  tags = var.tags
}

# test module
# example if sns topic was for access logging
module "event" {
  source = "./../.."

  name        = "eits-tf-aws-eventbridge-sns"
  description = "Capture each AWS Console Sign In"

  rule_targets = {
    eventbridge_send_to_sns = {
      arn = module.sns.topic_arn
      input_transformer = {
        input_template = "\"User ID: <instance-id>\""
        input_paths = {
          "instance-id" = "$.detail.userIdentity.arn"
        }
      }
    }
  }

  event_pattern_json = jsonencode({
    detail-type = [
      "AWS Console Sign In via CloudTrail"
    ]
  })

  tags = var.tags
}
