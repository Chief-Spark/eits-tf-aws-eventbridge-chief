# test region
provider "aws" {
  region = var.region
}

# deploy test lambda function
# tfsec:ignore:aws-lambda-enable-tracing
module "lambda" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git"

  function_scope = "eventbridge-schedule-test"
  filename       = "test.zip"
  handler        = "test.lambda_handler"
  runtime        = "python3.12"

  disable_default_alarms = true

  tags = var.tags
}

# give scheduler permission to trigger lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = module.event.schedule_arn
}

# create policy to allow scheduler to trigger lambda
data "aws_iam_policy_document" "allow_lambda" {
  statement {
    sid       = "AllowToInvokeLambda"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [module.lambda.arn]
  }
}

# test module
# example of triggering lambda via EventBridge Scheduler schedule
module "event" {
  source = "./../.."

  name                = "eits-tf-aws-eventbridge-lambda"
  description         = "Trigger lambda function every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  create_iam_role       = true
  role_trusted_services = ["lambda.amazonaws.com"]
  role_policy_documents = [data.aws_iam_policy_document.allow_lambda.json]

  schedule_targets = {
    eventbridge_lambda_trigger = {
      arn   = module.lambda.arn
      input = jsonencode({ "test_event" : "hello world!" })
    }
  }

  tags = var.tags
}
