# CloudWatch Log Delivery Sources for INFO, ERROR, and TRACE logs
resource "aws_cloudwatch_log_delivery_source" "info_logs" {
  count = local.enable_logging ? 1 : 0

  name         = "EventBusSource-${aws_cloudwatch_event_bus.this[0].name}-INFO_LOGS"
  log_type     = "INFO_LOGS"
  resource_arn = aws_cloudwatch_event_bus.this[0].arn
}

resource "aws_cloudwatch_log_delivery_source" "error_logs" {
  count = local.enable_logging ? 1 : 0

  name         = "EventBusSource-${aws_cloudwatch_event_bus.this[0].name}-ERROR_LOGS"
  log_type     = "ERROR_LOGS"
  resource_arn = aws_cloudwatch_event_bus.this[0].arn
}

resource "aws_cloudwatch_log_delivery_source" "trace_logs" {
  count = local.enable_logging ? 1 : 0

  name         = "EventBusSource-${aws_cloudwatch_event_bus.this[0].name}-TRACE_LOGS"
  log_type     = "TRACE_LOGS"
  resource_arn = aws_cloudwatch_event_bus.this[0].arn
}

# Logging to CloudWatch Log Group
module "event_bus_logs" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs?ref=2.6.1"
  count  = local.enable_cwlogs ? 1 : 0

  log_group_name    = "/aws/vendedlogs/events/event-bus/${aws_cloudwatch_event_bus.this[0].name}"
  retention_in_days = var.event_bus_log_config.cloudwatch_retention_in_days

  tags = local.tags
}

data "aws_iam_policy_document" "cwlogs" {
  count = local.enable_cwlogs ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${module.event_bus_logs[0].log_group_arn}:log-stream:*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_log_delivery_source.info_logs[0].arn,
        aws_cloudwatch_log_delivery_source.error_logs[0].arn,
        aws_cloudwatch_log_delivery_source.trace_logs[0].arn
      ]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  count = local.enable_cwlogs ? 1 : 0

  policy_document = data.aws_iam_policy_document.cwlogs[0].json
  policy_name     = "AWSLogDeliveryWrite-${aws_cloudwatch_event_bus.this[0].name}"
}

resource "aws_cloudwatch_log_delivery_destination" "cwlogs" {
  count = local.enable_cwlogs ? 1 : 0

  name = "EventsDeliveryDestination-${aws_cloudwatch_event_bus.this[0].name}-CWLogs"
  delivery_destination_configuration {
    destination_resource_arn = module.event_bus_logs[0].log_group_arn
  }
}

resource "aws_cloudwatch_log_delivery" "cwlogs_info_logs" {
  count = local.enable_cwlogs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.info_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.s3_info_logs
  ]
}

resource "aws_cloudwatch_log_delivery" "cwlogs_error_logs" {
  count = local.enable_cwlogs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.error_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.cwlogs_info_logs,
    aws_cloudwatch_log_delivery.s3_error_logs
  ]
}

resource "aws_cloudwatch_log_delivery" "cwlogs_trace_logs" {
  count = local.enable_cwlogs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.trace_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.cwlogs_error_logs,
    aws_cloudwatch_log_delivery.s3_trace_logs
  ]
}

# Logging to S3 Bucket
module "s3_logging_bucket" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git?ref=2.19.1"
  count  = local.enable_s3logs && var.event_bus_log_config.s3_bucket_arn == null ? 1 : 0

  bucket_name             = "${aws_cloudwatch_event_bus.this[0].name}-logs"
  disable_default_alarms  = true
  source_policy_documents = [data.aws_iam_policy_document.logging_bucket[0].json]
  versioning_enabled      = false
  lifecycle_rules = [
    {
      id = "log-expiration"
      expiration = {
        days = var.event_bus_log_config.s3_retention_in_days
      }
    }
  ]

  tags = local.tags
}

data "aws_iam_policy_document" "logging_bucket" {
  count = local.enable_s3logs && var.event_bus_log_config.s3_bucket_arn == null ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_cloudwatch_event_bus.this[0].name}-logs/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_log_delivery_source.info_logs[0].arn,
        aws_cloudwatch_log_delivery_source.error_logs[0].arn,
        aws_cloudwatch_log_delivery_source.trace_logs[0].arn
      ]
    }
  }
}

resource "aws_cloudwatch_log_delivery_destination" "s3" {
  count = local.enable_s3logs ? 1 : 0

  name = "EventsDeliveryDestination-${aws_cloudwatch_event_bus.this[0].name}-S3"
  delivery_destination_configuration {
    destination_resource_arn = var.event_bus_log_config.s3_bucket_arn != null ? var.event_bus_log_config.s3_bucket_arn : module.s3_logging_bucket[0].s3_bucket_arn
  }
}

resource "aws_cloudwatch_log_delivery" "s3_info_logs" {
  count = local.enable_s3logs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.s3[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.info_logs[0].name
}
resource "aws_cloudwatch_log_delivery" "s3_error_logs" {
  count = local.enable_s3logs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.s3[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.error_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.s3_info_logs
  ]
}
resource "aws_cloudwatch_log_delivery" "s3_trace_logs" {
  count = local.enable_s3logs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.s3[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.trace_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.s3_error_logs
  ]
}

# Logging to Data Firehose
resource "aws_cloudwatch_log_delivery_destination" "firehose" {
  count = local.enable_fhlogs ? 1 : 0

  name = "EventsDeliveryDestination-${aws_cloudwatch_event_bus.this[0].name}-Firehose"
  delivery_destination_configuration {
    destination_resource_arn = var.event_bus_log_config.firehose_arn
  }
}

resource "aws_cloudwatch_log_delivery" "firehose_info_logs" {
  count = local.enable_fhlogs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.firehose[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.info_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.cwlogs_info_logs
  ]
}

resource "aws_cloudwatch_log_delivery" "firehose_error_logs" {
  count = local.enable_fhlogs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.firehose[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.error_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.cwlogs_error_logs,
    aws_cloudwatch_log_delivery.firehose_info_logs
  ]
}

resource "aws_cloudwatch_log_delivery" "firehose_trace_logs" {
  count = local.enable_fhlogs ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.firehose[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.trace_logs[0].name
  depends_on = [
    aws_cloudwatch_log_delivery.cwlogs_trace_logs,
    aws_cloudwatch_log_delivery.firehose_error_logs
  ]
}
