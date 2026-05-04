#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# new-project.sh
# Bootstraps IAM resources and generates backend.hcl for a new downstream project.
#
# Creates the following AWS resources:
#   - IAM role tf-<project-name> with two trust relationships:
#       * GitHub Actions (OIDC) — scoped to the specified repo, any branch
#       * SSO developers — any IAM Identity Center user in the account
#   - IAM policy tf-<project-name>-state-access — S3/DynamoDB/KMS state access
#
# Intended for use by the infra team only.
#
# Usage:
#   ./new-project.sh <project-name> <github-repo-name>
#
# Requirements:
#   - Run from the root of this repo (terraform-backend-s3)
#   - terraform apply must have been run at least once so outputs are available
#   - AWS SSO session must be active: aws sso login --profile terraform-admin
#   - github_org must be set in terraform.tfvars
# ---------------------------------------------------------------------------

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <project-name> <github-repo-name>" >&2
  exit 1
fi

PROJECT_NAME="$1"
GITHUB_REPO="$2"
ROLE_NAME="tf-${PROJECT_NAME}"
POLICY_NAME="tf-${PROJECT_NAME}-state-access"

# ---------------------------------------------------------------------------
# Validate environment
# ---------------------------------------------------------------------------
if ! terraform version > /dev/null 2>&1; then
  echo "Error: terraform is not installed or not in PATH" >&2
  exit 1
fi

if ! terraform output > /dev/null 2>&1; then
  echo "Error: no Terraform outputs found." >&2
  echo "Ensure terraform apply has been run and your SSO session is active:" >&2
  echo "  aws sso login --profile terraform-admin" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read config from terraform.tfvars
# ---------------------------------------------------------------------------
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=""
GITHUB_ORG=""
BOOTSTRAP_PROFILE="terraform-admin"

if [ -f "terraform.tfvars" ]; then
  AWS_REGION=$(grep 'aws_region'       terraform.tfvars | awk -F'"' '{print $2}')
  AWS_ACCOUNT_ID=$(grep 'aws_account_id'  terraform.tfvars | awk -F'"' '{print $2}')
  GITHUB_ORG=$(grep 'github_org'       terraform.tfvars | awk -F'"' '{print $2}' || true)
  BOOTSTRAP_PROFILE=$(grep 'bootstrap_profile' terraform.tfvars | awk -F'"' '{print $2}' || echo "terraform-admin")
fi

if [ -z "${GITHUB_ORG}" ]; then
  echo "Error: github_org not set in terraform.tfvars" >&2
  exit 1
fi

if [ -z "${AWS_ACCOUNT_ID}" ]; then
  echo "Error: aws_account_id not set in terraform.tfvars" >&2
  exit 1
fi

S3_BUCKET=$(terraform output -raw s3_bucket_name)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
KMS_KEY_ARN=$(terraform output -raw kms_key_arn)
OIDC_PROVIDER_ARN=$(terraform output -raw oidc_provider_arn)

if [ -z "${S3_BUCKET}" ] || [ -z "${DYNAMODB_TABLE}" ] || [ -z "${KMS_KEY_ARN}" ] || [ -z "${OIDC_PROVIDER_ARN}" ]; then
  echo "Error: one or more required outputs are empty. Re-run terraform apply." >&2
  exit 1
fi

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

# ---------------------------------------------------------------------------
# Confirm with user
# ---------------------------------------------------------------------------
echo ""
echo "This will create the following AWS resources:"
echo ""
echo "  IAM role:   ${ROLE_NAME}"
echo "  IAM policy: ${POLICY_NAME}"
echo ""
echo "  Trust relationships:"
echo "    GitHub Actions: repo:${GITHUB_ORG}/${GITHUB_REPO}:* (any branch)"
echo "    SSO developers: any IAM Identity Center user in account ${AWS_ACCOUNT_ID}"
echo ""
echo "  State access:"
echo "    S3 bucket:      ${S3_BUCKET}"
echo "    DynamoDB table: ${DYNAMODB_TABLE}"
echo "    KMS key:        ${KMS_KEY_ARN}"
echo ""
read -rp "Proceed? [y/N] " CONFIRM
if [ "${CONFIRM}" != "y" ] && [ "${CONFIRM}" != "Y" ]; then
  echo "Aborted." >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Create IAM role with trust policy
# ---------------------------------------------------------------------------
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOIDC",
      "Effect": "Allow",
      "Principal": { "Federated": "${OIDC_PROVIDER_ARN}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    },
    {
      "Sid": "SSODevelopers",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root" },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:sts::${AWS_ACCOUNT_ID}:assumed-role/AWSReservedSSO_*/*"
        }
      }
    }
  ]
}
EOF
)

echo ""
echo "Creating IAM role ${ROLE_NAME}..."
aws iam create-role \
  --profile "${BOOTSTRAP_PROFILE}" \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document "${TRUST_POLICY}" \
  --query 'Role.Arn' \
  --output text > /dev/null

# ---------------------------------------------------------------------------
# Create and attach state access policy
# ---------------------------------------------------------------------------
STATE_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${S3_BUCKET}"
    },
    {
      "Sid": "S3StateAccess",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
    },
    {
      "Sid": "DynamoDBLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:${AWS_ACCOUNT_ID}:table/${DYNAMODB_TABLE}"
    },
    {
      "Sid": "KMSDecrypt",
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "${KMS_KEY_ARN}"
    }
  ]
}
EOF
)

echo "Creating IAM policy ${POLICY_NAME}..."
POLICY_ARN=$(aws iam create-policy \
  --profile "${BOOTSTRAP_PROFILE}" \
  --policy-name "${POLICY_NAME}" \
  --policy-document "${STATE_POLICY}" \
  --query 'Policy.Arn' \
  --output text)

echo "Attaching policy to role..."
aws iam attach-role-policy \
  --profile "${BOOTSTRAP_PROFILE}" \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "backend.hcl — distribute to the downstream team securely, do NOT commit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat <<EOF
bucket         = "${S3_BUCKET}"
dynamodb_table = "${DYNAMODB_TABLE}"
kms_key_id     = "${KMS_KEY_ARN}"
region         = "${AWS_REGION}"
encrypt        = true
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Role ARN — add to GitHub Actions workflow and local dev terraform.tfvars"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${ROLE_ARN}"

echo "" >&2
echo "Done. Next steps:" >&2
echo "" >&2
echo "  1. Distribute backend.hcl to the downstream team securely" >&2
echo "     (1Password, AWS Secrets Manager, or equivalent)" >&2
echo "  2. Add the role ARN to the GitHub Actions workflow (see README)" >&2
echo "  3. For local dev, add to infra/terraform.tfvars (gitignored):" >&2
echo "       role_arn = \"${ROLE_ARN}\"" >&2
echo "" >&2
echo "  See the README for the full downstream project setup." >&2
