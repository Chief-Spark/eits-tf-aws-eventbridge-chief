# move event rule resources to count - v1.2.0 
moved {
  from = aws_cloudwatch_event_rule.this
  to   = aws_cloudwatch_event_rule.this[0]
}
