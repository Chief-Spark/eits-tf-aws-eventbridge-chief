# test region
provider "aws" {
  region = var.region
}

# test module
# example of creating a rule with a custom event bus
module "event" {
  source = "./../.."

  name                               = "eits-tf-aws-eventbridge-create-bus"
  description                        = "Example of creating a custom event bus with logging and a DLQ"
  create_event_bus                   = true
  event_bus_name                     = "eits-tf-aws-eventbridge-bus"
  event_bus_create_dead_letter_queue = true
  event_bus_log_config = {
    level                        = "ERROR"
    include_detail               = "FULL"
    cloudwatch_retention_in_days = 30
    s3_logs                      = true
    s3_retention_in_days         = 60
  }

  event_pattern_json = jsonencode({
    detail-type = [
      "Test"
    ]
  })

  tags = var.tags
}
