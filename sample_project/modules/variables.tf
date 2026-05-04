variable "aws_account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "role_arn" {
  type        = string
  description = "ARN of the IAM role to assume when provisioning project resources"
}
