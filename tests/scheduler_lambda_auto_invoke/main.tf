# Tests that lambda:InvokeFunction is automatically added to the created IAM role
# when a Scheduler target points to a Lambda function (2.5.0)
#
# Key difference from the lambda_trigger test: no role_policy_documents entry for
# lambda:InvokeFunction is provided — the module auto-generates it from schedule_targets.

provider "aws" {
  region = var.region
}

# tfsec:ignore:aws-lambda-enable-tracing
module "lambda" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git"

  function_scope = "eb-scheduler-lambda-auto"
  filename       = "../lambda_trigger/test.zip"
  handler        = "test.lambda_handler"
  runtime        = "python3.12"

  disable_default_alarms = true

  tags = var.tags
}

# resource-based policy on Lambda side — still required for Scheduler to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = module.event.schedule_arn
}

# test module
# create_iam_role = true with a Lambda ARN as the target
# the module detects the Lambda ARN and auto-adds lambda:InvokeFunction to the created role
# no role_policy_documents needed for the Lambda permission (2.5.0)
module "event" {
  source = "./../.."

  name                = "eits-tf-aws-eb-lambda-auto"
  description         = "Test auto lambda:InvokeFunction added to created IAM role for Lambda targets"
  schedule_expression = "rate(5 minutes)"

  create_iam_role = true

  schedule_targets = {
    lambda_target = {
      arn   = module.lambda.arn
      input = jsonencode({ "test_event" : "hello world!" })
    }
  }

  tags = var.tags
}
