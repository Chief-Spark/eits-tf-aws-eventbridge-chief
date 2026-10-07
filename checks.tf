check "description_warning" {
  assert {
    condition     = var.description != null || var.event_bus_description != null
    error_message = "AWS Best Practice recommends providing a useful description for both rules and event buses."
  }
}

check "name_check" {
  assert {
    condition     = !((var.event_pattern_json != null || var.schedule_expression != null) && var.name == null)
    error_message = "The name variable must have a value! If omitted, Terraform will assign a random, unique name."
  }
}

check "event_bus" {
  assert {
    condition     = !(var.create_event_bus && var.event_bus_name == null && var.event_bus_partner_source_name == null)
    error_message = "If `create_event_bus` is `true`, then `either event_bus_name` or `event_bus_partner_source_name` must have a value"
  }
}

check "depreciated_vars" {
  assert {
    condition     = length(var.targets) == 0 && var.enabled == null
    error_message = <<EOF
  The 'targets' variable has been replaced with 'rule_targets'.
  The 'enabled' variable has been replaced with 'state'.
  Please see CHANGELOG.md for more information on how to migrate."
  EOF
  }
}

check "schedule_kms_key_arn_warning" {
  assert {
    condition     = var.enable_scheduler && var.schedule_expression != null ? var.schedule_kms_key_arn != null && try(length(var.schedule_kms_key_arn), 0) > 0 : true
    error_message = "You should provide a value for schedule_kms_key_arn to ensure EventBridge Scheduler uses a customer managed KMS key for encryption as per Wiz rule ServiceConfiguration-004"
  }
}


