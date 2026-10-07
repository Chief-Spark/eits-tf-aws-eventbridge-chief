# RELEASE NOTES

## 2.7.0 - 28th August 2026

- Added optional `role_name` and `permissions_boundary` variables for IAM role creation
- When `role_name` is set, it is used as the full IAM role name (EEC naming skipped); when `null`, the default `_{name}_Event` / `_{name}_PutEvents` convention is used
- Added `attach_policy_inline` to attach IAM permissions inline instead of creating managed policies
- Reused `event_rule_combined` policy document for both inline and managed policy attachment paths
- Added `role_name` output
- Inline policy merge includes scheduler Lambda invoke permissions from 2.6.0 when `attach_policy_inline` is enabled

## 2.6.1 - 14th September 2026

- Updated confluence document links

## 2.6.0 - 25th August 2026

- `existing_role_arn` now also applies to Scheduler (used as default `role_arn` when not set per target)
- `lambda:InvokeFunction` is automatically added to the created IAM role when Scheduler targets Lambda functions
- Added plan-time warning when Scheduler targets have no role configured

## 2.5.1 - 9th July 2026

- Pinned `eits-tf-aws-s3` to `2.19.1`
- Pinned `eits-tf-aws-iam` to `1.9.7`

## 2.5.0 - 22nd June 2026

- Added `input_transformer` variable
- Updated pre-commit config to version `1.4.0`

## 2.4.2 - 23rd April 2026

- Fixed incorrect variable reference to `subnets`
- Fixed incorrect variable reference to `enable_ecs_managed_tags`
- Fixed variable type for `enable_ecs_managed_tags`
- Fixed variable type for `enable_execute_command`

## 2.4.1 - 10th April 2026

- Updated `eits-tf-aws-sqs` module to version `1.6.0`
- Updated `eits-tf-aws-iam` module to version `1.9.6`
- Updated `eits-tf-aws-s3` module to version `2.18.0`
- Updated AWS provider version to `>= 6.36.0`

## 2.4.0 - 15th December 2025

- Updated `eits-tf-aws-iam` module to version `1.9.3`
- Add ability to enable logging for custom event bus to Cloudwatch, S3 or Firehose
- Add DLQ to custom event bus
- Updated aws provider to support latest enhancements and bugfixes
- Added action after completion schedule functionality

## 2.3.4 - 15th December 2025

- Bugfix: Stop warning on missing scheduler KMS key when not using the scheduler
- Updated check logic to work with older versions of Terraform
- Updated min required Terraform version to support submodules
- Updated pre-commit config to `1.3.1`

## 2.3.3 - 10th December 2025

- Updated `eits-tf-aws-iam` module to version `1.9.2`

## 2.3.2 - 8th September 2025

- Updated pinned version for `eits-tf-aws-iam`

## 2.3.1 - 28nd May 2025

- Module biannual review
- Updated AWS Provider version to `5.75.1`
- Added `description` attribute to `aws_cloudwatch_event_bus` resource
- Added `event_bus_description` variable
- Added checks to ensure a KMS key is present for `schedule_kms_key_arn` as per Wiz rule ServiceConfiguration-004
- Updated `eits-tf-aws-iam` version to `1.8.0`
- Updated tests to check new description variable works as expected

## 2.3.0 - 9th April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Updated required Terraform version to `1.5`
- Renamed `warnings.tf` to `checks.tf`
- Converted validation warnings and errors to `check` type
- Updated `pre-commit` version to `1.3.0`
- Bumped `eits-tf-aws-iam` version to `1.7.1`
- Removed `tlkamp\validation` provider
- Updated tests

## 2.2.1 - 20th Feburary 2025

- Added best practice warning if `var.description` is left empty.
- Updated version of tlkamp/validation to 1.1.3

## 2.2.0 - 16th October 2024

- Updated required aws provider version to : >= 5.60.0
- Added new event_bus_kms_key_identifier variable to allow for the use of AWS KMS customer managed key when creating a new event bus
- updated module to use latest version of eits-tf-aws-iam : 1.3.3

## 2.1.0 - 1st August 2024

- Add new `name_prefix` variable to allow overwriting of the EEC prefix if required.

## 2.0.1 - 8th April 2024

- Ignore terraform_unused_declarations tflint warning.

## 2.0.0 - 14th March 2024

- Use standalone EventBridge Scheduler resource instead of `schedule_expression` parameter in event rule (unless `enable_scheduler` is false).
- Only use rule and target resources if `event_pattern_json` is provided (or `enable_scheduler` is false).
- Replace `is_enabled` -> `state` due to depreciation.
- Rename `targets` -> `rule_targets` due to clarity.
- Allow ability to create just an event bus, without an event rule by making the `name` variable optional.
- Update required AWS provider version to [5.27.0](https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md#5270-november-27-2023) due to deprecated `is_enabled` parameter.
- Add `role_policy_documents` variable to allow additional policy to be added to created iam role
- Add the following new optional variables for EventBridge Scheduler:
  - `enable_scheduler`
  - `create_schedule_group`
  - `schedule_group_name`
  - `schedule_start_date`
  - `schedule_end_date`
  - `schedule_expression_timezone`
  - `schedule_kms_key_arn`
  - `schedule_targets`
- Add the following new outputs:
  - `schedule_id`
  - `schedule_arn`

### Migrating to 2.0.0

- If `schedule_expression` is provided this now uses EventBridge Scheduler, and the old rule and target resources will be replaced/destroyed. To disable the use of the new Scheduler, and carry on using an EventBridge rule, set `enable_scheduler` to `false`.
- Usage of the `targets` variable has changed:
  - The variable has been renamed: `targets` -> `rule_targets`
  - `rule_targets` should be used when creating an event rule, it is not used when creating a Scheduler schedule.
  - The new variable `schedule_targets` should be used when creating a Scheduler schedule.
- Usage of the module has changed due to the `is_enabled` variable being depreciated:
  - The variable has been renamed: `is_enabled` -> `state`
  - The variable type has changed from bool to string, with the default value `ENABLED`. See variable description for details.

## 1.1.0 - 5th March 2024

- Updated IAM module to version 1.3.2. Please see Jira ticket [UKICLOENA-1511](https://agile.experian.com/browse/UKICLOENA-1511) for more information.

## 1.0.0 - 13th November 2023

- Initial release
