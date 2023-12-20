provider "aws" {
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"

  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/tf-svc-role-state"
  }
}
