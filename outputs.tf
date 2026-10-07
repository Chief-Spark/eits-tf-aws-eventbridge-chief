output "bus_arn" {
  value       = try(aws_cloudwatch_event_bus.this[0].arn, null)
  description = "The ARN of the event bus, if created."
}

output "cloudwatch_log_group_arn" {
  value       = try(module.event_bus_logs[0].log_group_arn, null)
  description = "The ARN of the CloudWatch log group for the event bus, if created."
}

output "cloudwatch_log_group_name" {
  value       = try(module.event_bus_logs[0].log_group_name, null)
  description = "The name of the CloudWatch log group for the event bus, if created."
}

output "dead_letter_queue_arn" {
  value       = try(module.dlq[0].queue_arn, var.event_bus_dead_letter_queue_arn)
  description = "The ARN of the dead letter queue for the event bus, if created or supplied."
}

output "role_arn" {
  value       = try(module.iam_role[0].role_arn, null)
  description = "The ARN of the iam role, if created."
}

output "role_name" {
  value       = try(module.iam_role[0].role_name, null)
  description = "The name of the iam role, if created."
}

output "rule_id" {
  value       = try(aws_cloudwatch_event_rule.this[0].id, null)
  description = "The name of the event rule, if created."
}

output "rule_arn" {
  value       = try(aws_cloudwatch_event_rule.this[0].arn, null)
  description = "The ARN of the event rule, if created."
}

output "s3_logging_bucket_arn" {
  value       = try(module.s3_logging_bucket[0].s3_bucket_arn, null)
  description = "The ARN of the S3 logging bucket for the event bus, if created."
}

output "schedule_id" {
  value       = try(aws_scheduler_schedule.this[0].id, null)
  description = "The name of the schedule, if created."
}

output "schedule_arn" {
  value       = try(aws_scheduler_schedule.this[0].arn, null)
  description = "The ARN of the schedule, if created."
}
