# Sample Projects

Two sample projects that demonstrate Terraform remote state using the shared S3 backend.
Each project provisions a VPC, subnets, security group, internet gateway, and a small EC2 instance.

## Before You Begin

### 1. Bootstrap the backend

The shared backend (S3 bucket, DynamoDB table, KMS key, GitHub OIDC provider) must already
be deployed. From the repo root:

```bash
aws sso login --profile terraform-admin
terraform init
terraform apply
```

### 2. Create a per-project IAM role

Run `new-project.sh` from the repo root to create the IAM role and state-access policy for
the sample project. You need to do this once per project.

```bash
# Usage: ./new-project.sh <project-name> <github-repo-name>
./new-project.sh sample-project-a <your-github-repo>
./new-project.sh sample-project-b <your-github-repo>
```

The script will print a `backend.hcl` block and the role ARN. Add the role ARN to the
project's `terraform.tfvars`:

```hcl
# sample_project/sample-project-a/terraform.tfvars (gitignored)
aws_account_id = "<YOUR_ACCOUNT_ID>"
aws_region     = "us-east-1"
project_name   = "sample-project-a"
role_arn       = "<ROLE_ARN_FROM_SCRIPT>"
```

---

## sample-project-a

```bash
cd sample_project/sample-project-a
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

## sample-project-b

```bash
cd sample_project/sample-project-b
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```
