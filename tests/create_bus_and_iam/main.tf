# test region
provider "aws" {
  region = var.region
}

# test module
# example of creating a rule with a custom event bus
module "event" {
  source = "./../.."

  name             = "eits-tf-aws-eventbridge-create-bus"
  description      = "Example of creating a custom event bus"
  create_iam_role  = true
  create_event_bus = true
  event_bus_name   = "eits-tf-aws-eventbridge-bus"

  event_pattern_json = jsonencode({
    detail-type = [
      "Test"
    ]
  })

  tags = var.tags
}
