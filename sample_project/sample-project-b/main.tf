terraform {
  backend "s3" {
    dynamodb_table = "terraform-state"
  }
}

module "sample_project_module_resources" {
  source = "../modules/"

  aws_account_id = var.aws_account_id
  project_name   = var.project_name
  aws_region     = var.aws_region
  role_arn       = var.role_arn
}
