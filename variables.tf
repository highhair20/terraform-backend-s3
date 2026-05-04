variable "aws_account_id" {
  type        = string
  description = "AWS account ID where the backend resources are deployed"
}

variable "aws_region" {
  type        = string
  description = "AWS region where the backend resources are deployed"
}

variable "s3_bucket" {
  type        = string
  description = "Name of the S3 bucket used to store Terraform state"
}

variable "bootstrap_profile" {
  type        = string
  default     = "terraform-admin"
  description = "AWS CLI profile used to run Terraform against this module"
}

variable "github_org" {
  type        = string
  description = "GitHub organisation (or user) that owns the downstream repos"
}
