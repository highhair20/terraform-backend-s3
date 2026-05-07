# Using This Backend in Your Own Project

This guide walks you through connecting any Terraform project — in its own separate repository — to the shared S3 backend you have already deployed.

## Prerequisites

- The shared backend is deployed (you have run `terraform apply` in this repo)
- Your AWS SSO session is active: `aws sso login --profile terraform-admin`
- Your downstream project is a GitHub repository (required for OIDC-based CI/CD)

---

## Step 1 — Register the project

From the root of this (`terraform-backend-s3`) repository, run `new-project.sh`. This is a one-time step per project.

```bash
./new-project.sh <project-name> <github-repo-name>
```

Example:

```bash
./new-project.sh my-api my-api-repo
```

The script creates two AWS resources:
- IAM role `tf-my-api` — trusted by GitHub Actions (OIDC) and any SSO developer in your account
- IAM policy `tf-my-api-state-access` — grants read/write access to this project's state keys only

When it finishes it prints two things you will need in the following steps.

**backend.conf block** — the backend configuration for this project:
```hcl
bucket       = "<YOUR-ORG>-tf-state"
use_lockfile = true
kms_key_id   = "<KMS-KEY-ARN>"
region       = "us-east-1"
encrypt      = true
key            = "my-api/dev/terraform.tfstate"
```

**Role ARN** — the IAM role your project will assume when provisioning resources:
```
arn:aws:iam::<ACCOUNT_ID>:role/tf-my-api
```

---

## Step 2 — Add the backend block to your project

In your downstream project repository, open (or create) your Terraform root `main.tf` and add an empty `backend "s3"` block. The block must be empty — all configuration is supplied at init time via `backend.conf`.

```hcl
# main.tf
terraform {
  backend "s3" {}
}
```

---

## Step 3 — Create backend.conf

In the same directory as your `main.tf`, create `backend.conf` and paste the block printed by `new-project.sh`:

```hcl
bucket       = "<YOUR-ORG>-tf-state"
use_lockfile = true
kms_key_id   = "<KMS-KEY-ARN>"
region       = "us-east-1"
encrypt      = true
key            = "my-api/dev/terraform.tfstate"
```

This file is **safe to commit** — it contains no credentials, only resource identifiers.

> To deploy to a different environment, change `dev` in the `key` to `staging`, `prod`, etc.
> See [Multiple environments](#multiple-environments) below.

---

## Step 4 — Configure your provider and variables

Your project needs to assume the IAM role when provisioning resources. Add the following to your `main.tf` (or a dedicated `providers.tf`):

```hcl
provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.role_arn
  }
}
```

Declare the corresponding variables (typically in `variables.tf`):

```hcl
variable "aws_account_id" {
  type        = string
  description = "AWS account ID where project resources are deployed"
}

variable "aws_region" {
  type        = string
  description = "AWS region where project resources are deployed"
}

variable "project_name" {
  type        = string
  description = "Short unique identifier for the project"
}

variable "role_arn" {
  type        = string
  description = "ARN of the IAM role to assume when provisioning project resources"
}
```

---

## Step 5 — Create terraform.tfvars

Create `terraform.tfvars` in the same directory. **Do not commit this file** — add it to your project's `.gitignore`.

```hcl
aws_account_id = "<YOUR AWS ACCOUNT ID>"
aws_region     = "us-east-1"
project_name   = "my-api"
role_arn       = "<ROLE_ARN_FROM_NEW_PROJECT_SH>"
```

Add to `.gitignore`:
```
terraform.tfvars
```

---

## Step 6 — Initialise and run

```bash
aws sso login --profile terraform-admin
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

> SSO sessions expire after 8–12 hours. If you see authentication errors on a later run,
> re-run `aws sso login --profile terraform-admin` to refresh your credentials.

---

## Step 7 — Set up GitHub Actions (optional)

Copy the template workflow from this repository into your project:

```bash
cp <path-to-terraform-backend-s3>/examples/.github/workflows/terraform.yml \
   .github/workflows/terraform.yml
```

In your GitHub repository go to **Settings → Secrets and variables → Actions → Variables** and add:

| Variable | Value |
|---|---|
| `TF_ROLE_ARN` | Role ARN printed by `new-project.sh` |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `AWS_REGION` | e.g. `us-east-1` |
| `TF_PROJECT_NAME` | Your project name (e.g. `my-api`) |

If your Terraform root is in a subdirectory (e.g. `infra/`), open the workflow file and uncomment the `working-directory` block, setting it to your subdirectory path.

Commit and push. The workflow will:
- Run `terraform fmt`, `validate`, and `plan` on every push and pull request
- Post the plan output as a PR comment so reviewers can see exactly what will change
- Run `terraform apply` automatically on merge to `main`

> **Recommended:** Enable branch protection on `main` (require PRs + passing status checks)
> so that `terraform apply` only ever runs after a plan has been reviewed and approved.

---

## Multiple environments

The state key is structured as `<project-name>/<env>/terraform.tfstate`. To manage multiple environments from the same project, create one `backend.conf` file per environment:

```
backend-dev.conf
backend-staging.conf
backend-prod.conf
```

Each file is identical except for the `key`. Initialise with the appropriate file:

```bash
terraform init -backend-config=backend-prod.conf
terraform apply -var-file=prod.tfvars
```

The IAM role created by `new-project.sh` is project-scoped and grants access to all keys under `my-api/*`, so dev and prod share the same role by default.

If you need strict IAM isolation between environments (e.g. to prevent a dev deployment from ever touching prod state), register each environment as a separate project:

```bash
./new-project.sh my-api-prod my-api-repo
```

This creates a dedicated `tf-my-api-prod` role whose state access policy is scoped exclusively to `my-api-prod/*`.
