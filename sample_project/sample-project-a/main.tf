terraform {
  backend "s3" {
    profile         = "tf-svc-user"
    region          = "us-east-1"
    dynamodb_table  = "terraform_state"
  }
}

module "sample_project_module_resources" {
  source = "../modules/"

  aws_account_id = var.aws_account_id
  project_name = var.project_name
  aws_profile = var.aws_profile
  aws_region = var.aws_region
}
