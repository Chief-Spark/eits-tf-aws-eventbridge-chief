variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "region" {
  type        = string
  description = "AWS region to provision into"
}
