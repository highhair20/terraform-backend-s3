# terraform-backend-s3
___

## Overview
This project creates the AWS infrastructure required to use S3 as a Terraform remote backend. Run
this once before any other Terraform project — the resulting S3 bucket and DynamoDB table can serve
an unlimited number of projects.

**S3** stores the Terraform state file centrally, providing a single source of truth across runs and
contributors. Versioning is enabled so every state change is preserved and can be rolled back.
State is encrypted at rest using a dedicated KMS key.

**DynamoDB** provides state locking. When a Terraform operation is in progress, a lock record is
written to DynamoDB so no two processes can modify state simultaneously. If a process crashes the
lock expires automatically, preventing it from being held indefinitely.

## Before You Begin

This project uses **AWS IAM Identity Center** (formerly AWS SSO) for authentication. Identity Center
issues short-lived temporary credentials on login — no long-lived access keys are stored on disk.
No long-lived IAM credentials are needed — the shared backend infrastructure is created by Terraform itself.

### 1. Enable IAM Identity Center
1. In the AWS console search for **IAM Identity Center** and open it
2. Click **Enable** — this is a one-time setup per AWS account
3. AWS will prompt you with: _"This account will be the management account of your organization."_
   This is expected. IAM Identity Center requires AWS Organizations. For a single-account personal
   setup this has no practical impact — click through and confirm.

### 2. Create a Permission Set
A Permission Set defines what actions are allowed when you log in with this profile. This one grants
the permissions Terraform needs to create all resources in this project: IAM user, role, and
policies; S3 bucket and its configuration; DynamoDB table; and KMS key.

1. IAM Identity Center → **Permission sets** → **Create permission set**
2. Choose **Custom permission set**
3. Under **Inline policy**, paste the contents of [`bootstrap-permission-set-policy.json`](bootstrap-permission-set-policy.json)
4. Click **Next** → name it `TerraformBootstrap` → **Create**

### 3. Create a User in Identity Center
1. IAM Identity Center → **Users** → **Add user**
2. Use `terraform-admin` as the username and enter your email address for the remaining required fields
3. You will receive an email to activate the account — complete that before continuing

### 4. Assign the User to Your Account
1. IAM Identity Center → **AWS accounts** → select your account
2. Click **Assign users or groups** → select your user → select the `TerraformBootstrap` permission set
3. Click **Submit**

### 5. Configure the AWS CLI
```bash
aws configure sso
```
When prompted:
```
SSO session name:               terraform-admin
SSO start URL:                  https://<YOUR-SSO-PORTAL>.awsapps.com/start
SSO region:                     us-east-1
SSO registration scopes:        sso:account:access  ← press Enter to accept the default
SSO account ID:                 <YOUR AWS ACCOUNT ID>
SSO role name:                  TerraformBootstrap
CLI default client Region:      us-east-1
CLI default output format:      json
CLI profile name:               terraform-admin
```
Your SSO start URL is shown on the IAM Identity Center dashboard under **Settings**.

### 6. Have the following info handy
You will be prompted for these values when running Terraform.
Alternatively, create a `terraform.tfvars` file — do not check it into git.
```
aws_account_id    = "<YOUR AWS ACCOUNT ID>"
aws_region        = "us-east-1"
s3_bucket         = "<YOUR-ORG>-tf-state"
bootstrap_profile = "terraform-admin"
github_org        = "<YOUR-GITHUB-ORG>"
```

## Create Your Terraform Backend
1. Clone this project
2. Log in with your bootstrap profile
```bash
aws sso login --profile terraform-admin
```
3. Execute Terraform commands
```bash
cd terraform-backend-s3
terraform init
terraform plan
terraform apply
```
That's it. Terraform will create the S3 bucket, DynamoDB table, KMS key, and GitHub OIDC provider.
You should now have a fully configured remote backend ready for use by any number of projects.

## See it in action
This section is optional and is only to see how objects and state manifest themselves in s3 and DynamoDB
for actual projects. 

For a detailed walk-through of setting up the sample projects go 
[here](sample_project/README.md).

Once you are done your s3 bucket should look something like:

![S3 bucket containing two sample projects](https://highhair20-github-images.s3.amazonaws.com/terraform-backend-s3/s3.png)


and your DynamoDB table should look something like:

![DynamoDB table containing two sample projects](https://highhair20-github-images.s3.amazonaws.com/terraform-backend-s3/dynamodb.png)


## Multi-environment projects

The S3 state key is structured as `<project-name>/<env>/terraform.tfstate`, so a single bucket
cleanly holds state for every project and environment without any naming collisions.

The IAM role created by `new-project.sh` (`tf-<project-name>`) is **project-scoped** — it grants
access to all state keys under that project prefix, regardless of environment. Dev and prod
deployments share the same role.

To deploy a project to multiple environments, create one `backend.conf` file per environment:

```
backend-dev.conf
backend-staging.conf
backend-prod.conf
```

Each file is identical except for the `key`:

```hcl
# backend-prod.conf
bucket         = "<YOUR-ORG>-tf-state"
dynamodb_table = "terraform-state"
kms_key_id     = "<KMS-KEY-ARN>"
region         = "us-east-1"
encrypt        = true
key            = "<project-name>/prod/terraform.tfstate"
```

Initialise Terraform with the appropriate file for each environment:

```bash
terraform init -backend-config=backend-prod.conf
terraform apply -var-file=prod.tfvars
```

If you need strict environment isolation at the IAM level (e.g. prevent a dev deployment from
touching prod state), run `new-project.sh` with an environment suffix:

```bash
./new-project.sh my-api-prod my-api-repo
```

This creates a separate `tf-my-api-prod` role whose state policy is scoped exclusively to
`my-api-prod/*`.

## Good things to know
### How to start over
You may have created your state bucket and added some test projects but want to start fresh.
You might think that you can simply run ```terraform destroy``` and, boom, you're done.
However, that's not the case. 

Due to the proper configuration of managing remote state, we are keeping a history in s3 which prevents
```terraform destroy``` from completing successfully due to the s3 versions that are saved.
To get past this you have to delete the versions manually. To do so:
1. In s3 click on the bucket containing your state.
2. Click on the Object you wish to delete. 
3. Click on the "Show versions" slider near the search bar.
4. To "select all" click the checkbox near "Name".
5. Click "Delete".
6. Scroll to the bottom. Type "permanently delete" in the text box and click "Delete objects".

Follow the previous steps to delete all other objects from the bucket.