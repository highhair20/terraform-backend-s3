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

## Step 1a — Grant the project role access to your AWS services

The role created in Step 1 (`tf-<project-name>`) has one policy attached by default:

- **`tf-<project-name>-state-access`** — read/write access to the project's Terraform state keys in S3

It has no permissions to create or manage any application infrastructure.

Before running `terraform plan` or `terraform apply` you must attach a second policy that grants the role permission to manage the AWS services your project actually uses (EC2, EKS, RDS, CloudFront, etc.).

**Create the policy document**

Create a JSON file (e.g. `tf-<project-name>-infra-policy.json` in your project repo) listing the IAM actions your Terraform code requires. Include one `Statement` block per service — this makes it easy to audit and extend as your project grows.

Only include services your project actually uses. The example below shows the structure for a project using S3, CloudFront, and Route53 — add or remove blocks to match your stack:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:DeleteBucketPolicy",
        "s3:GetBucketPolicy",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketTagging",
        "s3:GetBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:ListBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketTagging",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudFront",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateCachePolicy",
        "cloudfront:CreateDistribution",
        "cloudfront:CreateOriginAccessControl",
        "cloudfront:DeleteCachePolicy",
        "cloudfront:DeleteDistribution",
        "cloudfront:DeleteOriginAccessControl",
        "cloudfront:GetCachePolicy",
        "cloudfront:GetDistribution",
        "cloudfront:GetDistributionConfig",
        "cloudfront:GetOriginAccessControl",
        "cloudfront:ListDistributions",
        "cloudfront:ListTagsForResource",
        "cloudfront:TagResource",
        "cloudfront:UpdateCachePolicy",
        "cloudfront:UpdateDistribution",
        "cloudfront:UpdateOriginAccessControl"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53",
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ChangeTagsForResource",
        "route53:CreateHostedZone",
        "route53:DeleteHostedZone",
        "route53:GetChange",
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListHostedZonesByName",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    }
  ]
}
```

> **Scope note:** All statements use `Resource: "*"` because the ARNs of the resources Terraform is
> about to create are not known at policy-creation time. Access is constrained by the action list,
> not the resource ARN.

**Create and attach the policy**

```bash
# Create the policy
POLICY_ARN=$(aws iam create-policy \
  --profile terraform-admin \
  --policy-name tf-<project-name>-infra-access \
  --policy-document file://tf-<project-name>-infra-policy.json \
  --query 'Policy.Arn' \
  --output text)

# Attach it to the project role
aws iam attach-role-policy \
  --profile terraform-admin \
  --role-name tf-<project-name> \
  --policy-arn "$POLICY_ARN"
```

The policy document is safe to commit — it contains no credentials.

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

## Step 3 — Create backend conf files

In the same directory as your `main.tf`, create one file per environment using the block
printed by `new-project.sh`. Change only the `key` between files:

```
backend-dev.conf
backend-staging.conf
backend-prod.conf
```

```hcl
bucket       = "<YOUR-ORG>-tf-state"
use_lockfile = true
kms_key_id   = "<KMS-KEY-ARN>"
region       = "us-east-1"
encrypt      = true
key          = "my-api/dev/terraform.tfstate"   # change env per file
```

These files are **safe to commit** — they contain no credentials, only resource identifiers.

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
export AWS_PROFILE=terraform-admin
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

> SSO sessions expire after 8–12 hours. If you see authentication errors on a later run,
> re-run `aws sso login --profile terraform-admin && export AWS_PROFILE=terraform-admin` to refresh your credentials.

---

## Step 7 — Set up GitHub Actions (optional)

Copy the template workflow from this repository into your project:

```bash
cp <path-to-terraform-backend-s3>/examples/.github/workflows/terraform.yml \
   .github/workflows/terraform.yml
```

In your GitHub repository go to **Settings → Secrets and variables → Actions → Variables** (the
**Variables** tab, not Secrets) and add:

| Repository Variable | Value |
|---|---|
| `TF_ROLE_ARN` | Role ARN printed by `new-project.sh` |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `AWS_REGION` | e.g. `us-east-1` |
| `TF_PROJECT_NAME` | Your project name (e.g. `my-api`) |

None of these are secrets — they contain no credentials and are safe to store as plain variables.

If your Terraform files are in a subdirectory (e.g. `infra/`), open the workflow file and uncomment
the `defaults` block near the top of the job, setting `working-directory` to your subdirectory:

```yaml
defaults:
  run:
    working-directory: infra
```

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
