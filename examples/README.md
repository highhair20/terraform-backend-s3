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
# Usage: ./new-project.sh <project-name> <github-repo-name> [aws-profile]
./new-project.sh sample-project-a <your-github-repo>
./new-project.sh sample-project-b <your-github-repo>
```

The script will print a `backend.conf` block and the role ARN.

Copy the printed `backend.conf` content into the project's `backend.conf` file (it is safe
to commit — it contains no credentials). The `key` field defaults to `dev`; update it if
deploying to a different environment.

Add the role ARN and other values to the project's `terraform.tfvars` (do not commit this file):

```hcl
# examples/sample-project-a/terraform.tfvars (gitignored)
aws_account_id = "<YOUR_ACCOUNT_ID>"
aws_region     = "us-east-1"
project_name   = "sample-project-a"
role_arn       = "<ROLE_ARN_FROM_SCRIPT>"
```

---

## Local development

```bash
cd examples/sample-project-a
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

```bash
cd examples/sample-project-b
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

---

## GitHub Actions (CI/CD)

An example workflow is provided at `.github/workflows/terraform.yml`. It:
- Runs `terraform plan` on every push and pull request
- Runs `terraform apply` automatically on merge to `main`
- Authenticates via GitHub OIDC — no long-lived AWS credentials required

### Setup

1. Copy `examples/.github/workflows/terraform.yml` into your downstream project repository as `.github/workflows/terraform.yml`.

2. Set the following **Actions variables** in your GitHub repository
   (Settings → Secrets and variables → Actions → Variables):

   | Variable | Value |
   |---|---|
   | `TF_ROLE_ARN` | Role ARN printed by `new-project.sh` |
   | `AWS_ACCOUNT_ID` | Your AWS account ID |
   | `AWS_REGION` | e.g. `us-east-1` |
   | `TF_PROJECT_NAME` | e.g. `sample-project-a` |

3. Adjust the `working-directory` in the workflow file to match the path of your
   Terraform root within the repository.

4. Commit and push. The workflow will authenticate using the OIDC role on its first run.
