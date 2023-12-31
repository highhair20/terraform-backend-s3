terraform {
  backend "s3" {
    profile         = "tf-svc-user"
    dynamodb_table  = "terraform_state"
  }
}

module "sample_project_module_resources" {
  source = "../modules/"

  aws_account_id = var.aws_account_id
  project_name = var.project_name
  aws_region = var.aws_region
}