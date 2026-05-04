variable "project_name" {
  type        = string
  description = "Short unique identifier for the project (e.g. my-api)"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or username that owns the downstream project repo"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name for the downstream project"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the GitHub OIDC provider (output of the terraform-backend-s3 project)"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID"
}

variable "s3_bucket" {
  type        = string
  description = "Name of the S3 bucket storing Terraform state"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt state objects"
}
