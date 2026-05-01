variable "aws_account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "bootstrap_profile" {
  type    = string
  default = "tf-bootstrap"
}