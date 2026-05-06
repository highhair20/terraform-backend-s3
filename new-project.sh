#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# new-project.sh
# Bootstraps IAM resources and generates backend.conf for a new downstream project.
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
#   ./new-project.sh <project-name> <github-repo-name> [aws-profile]
#
# Arguments:
#   project-name      Short unique identifier for the project (e.g. my-api)
#   github-repo-name  GitHub repo name or full URL (e.g. my-repo or https://github.com/org/my-repo)
#   aws-profile       AWS CLI profile to use (default: terraform-admin)
#
# Requirements:
#   - Run from the root of this repo (terraform-backend-s3)
#   - terraform apply must have been run at least once so outputs are available
#   - AWS SSO session must be active: aws sso login --profile <aws-profile>
# ---------------------------------------------------------------------------

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 <project-name> <github-repo-name> [aws-profile]" >&2
  exit 1
fi

PROJECT_NAME="$1"
GITHUB_REPO="$2"
BOOTSTRAP_PROFILE="${3:-terraform-admin}"

# Accept full GitHub URLs (HTTPS or SSH) — extract the repo name from them
if [[ "$GITHUB_REPO" =~ ^https?://github\.com/[^/]+/([^/]+)$ ]]; then
  GITHUB_REPO="${BASH_REMATCH[1]}"
elif [[ "$GITHUB_REPO" =~ ^git@github\.com:[^/]+/([^/]+)$ ]]; then
  GITHUB_REPO="${BASH_REMATCH[1]}"
fi
GITHUB_REPO="${GITHUB_REPO%.git}"  # strip trailing .git if present

if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: project-name must contain only letters, numbers, hyphens, and underscores" >&2
  exit 1
fi

ROLE_NAME="tf-${PROJECT_NAME}"
POLICY_NAME="tf-${PROJECT_NAME}-state-access"

# ---------------------------------------------------------------------------
# Validate environment
# ---------------------------------------------------------------------------
if ! command -v aws > /dev/null 2>&1; then
  echo "Error: aws CLI is not installed or not in PATH" >&2
  exit 1
fi

if ! terraform version > /dev/null 2>&1; then
  echo "Error: terraform is not installed or not in PATH" >&2
  exit 1
fi

if ! terraform output > /dev/null 2>&1; then
  echo "Error: no Terraform outputs found." >&2
  echo "Ensure terraform apply has been run and your SSO session is active:" >&2
  echo "  aws sso login --profile ${BOOTSTRAP_PROFILE}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read all config from Terraform outputs
# ---------------------------------------------------------------------------
AWS_REGION=$(terraform output -raw aws_region)
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)
GITHUB_ORG=$(terraform output -raw github_org)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
KMS_KEY_ARN=$(terraform output -raw kms_key_arn)
OIDC_PROVIDER_ARN=$(terraform output -raw oidc_provider_arn)

if [ -z "${AWS_REGION}" ] || [ -z "${AWS_ACCOUNT_ID}" ] || [ -z "${GITHUB_ORG}" ] || \
   [ -z "${S3_BUCKET}" ] || [ -z "${DYNAMODB_TABLE}" ] || [ -z "${KMS_KEY_ARN}" ] || [ -z "${OIDC_PROVIDER_ARN}" ]; then
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
# Create IAM role with trust policy (idempotent)
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
if aws iam get-role --profile "${BOOTSTRAP_PROFILE}" --role-name "${ROLE_NAME}" > /dev/null 2>&1; then
  echo "IAM role ${ROLE_NAME} already exists, skipping creation."
else
  echo "Creating IAM role ${ROLE_NAME}..."
  aws iam create-role \
    --profile "${BOOTSTRAP_PROFILE}" \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --query 'Role.Arn' \
    --output text > /dev/null
fi

# ---------------------------------------------------------------------------
# Create and attach state access policy (idempotent)
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

EXISTING_POLICY_ARN=$(aws iam list-policies \
  --profile "${BOOTSTRAP_PROFILE}" \
  --scope Local \
  --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" \
  --output text)

if [ -n "${EXISTING_POLICY_ARN}" ]; then
  echo "IAM policy ${POLICY_NAME} already exists, skipping creation."
  POLICY_ARN="${EXISTING_POLICY_ARN}"
else
  echo "Creating IAM policy ${POLICY_NAME}..."
  POLICY_ARN=$(aws iam create-policy \
    --profile "${BOOTSTRAP_PROFILE}" \
    --policy-name "${POLICY_NAME}" \
    --policy-document "${STATE_POLICY}" \
    --query 'Policy.Arn' \
    --output text)
fi

ALREADY_ATTACHED=$(aws iam list-attached-role-policies \
  --profile "${BOOTSTRAP_PROFILE}" \
  --role-name "${ROLE_NAME}" \
  --query "AttachedPolicies[?PolicyArn=='${POLICY_ARN}'].PolicyArn" \
  --output text 2>/dev/null || true)

if [ -n "${ALREADY_ATTACHED}" ]; then
  echo "Policy already attached to role, skipping."
else
  echo "Attaching policy to role..."
  aws iam attach-role-policy \
    --profile "${BOOTSTRAP_PROFILE}" \
    --role-name "${ROLE_NAME}" \
    --policy-arn "${POLICY_ARN}"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "backend.conf — safe to commit, contains no credentials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat <<EOF
bucket         = "${S3_BUCKET}"
dynamodb_table = "${DYNAMODB_TABLE}"
kms_key_id     = "${KMS_KEY_ARN}"
region         = "${AWS_REGION}"
encrypt        = true
key            = "${PROJECT_NAME}/dev/terraform.tfstate"
EOF
echo ""
echo "  (change 'dev' in the key to match your target environment)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Role ARN — add to GitHub Actions workflow and local dev terraform.tfvars"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${ROLE_ARN}"

echo "" >&2
echo "Done. Next steps:" >&2
echo "" >&2
echo "  1. In your project repo, create backend.conf in the same directory as" >&2
echo "     your main.tf and paste the block above into it. Commit the file —" >&2
echo "     it contains no credentials. Example path:" >&2
echo "       your-repo/backend.conf          (Terraform at repo root)" >&2
echo "       your-repo/infra/backend.conf    (Terraform in a subdirectory)" >&2
echo "  2. Add the role ARN to the GitHub Actions workflow (see README)" >&2
echo "  3. For local dev, add to your project's terraform.tfvars (gitignored):" >&2
echo "       role_arn = \"${ROLE_ARN}\"" >&2
echo "" >&2
echo "  See the README for the full downstream project setup." >&2
