# test region
provider "aws" {
  region = var.region
}

# create cloudwatch log group with resource policy
module "cloudwatch_logs" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs"

  log_group_name    = "/aws/ec2/eits-tf-aws-eventbridge-logs"
  retention_in_days = 1

  resource_policy_principals = {
    Service = [
      "events.amazonaws.com",
      "delivery.logs.amazonaws.com"
    ]
  }

  tags = var.tags
}

# test module
module "event" {
  source = "./../.."

  name        = "eits-tf-aws-eventbridge-logs"
  description = "Capture each time EC2 is terminated"

  rule_targets = {
    eventbridge_to_loggroup = {
      arn = module.cloudwatch_logs.log_group_arn
    }
  }

  # example event that triggers when an ec2 is terminated
  event_pattern_json = jsonencode(
    {
      "source" : ["aws.ec2"],
      "detail-type" : ["EC2 Instance State-change Notification"],
      "detail" : {
        "state" : ["terminated"]
      }
    }
  )

  tags = var.tags
}
