module "sample_project_module_resources" {
  source = "../modules/"

  project_name = var.project_name
  aws_profile = var.aws_profile
  aws_region = var.aws_region
}

terraform {
  backend "s3" {
    profile         = "tf-svc-user-sample-project-a"
    region          = "us-east-1"
    dynamodb_table  = "terraform_state"
  }
}