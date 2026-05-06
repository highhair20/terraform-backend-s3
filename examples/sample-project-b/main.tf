terraform {
  backend "s3" {}
}

module "web_infra" {
  source = "../modules/web-infra/"

  aws_account_id = var.aws_account_id
  project_name   = var.project_name
  aws_region     = var.aws_region
  role_arn       = var.role_arn
}
