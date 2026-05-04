# ---------------------------------------------------------------------------
# project-role module
# Creates a per-project IAM role with two trust relationships:
#   1. GitHub Actions (OIDC) — scoped to a specific repo, any branch
#   2. SSO developers — any IAM Identity Center user in the account
#
# Also attaches a state access policy granting minimum permissions to use
# the Terraform S3 backend (S3, DynamoDB, KMS).
#
# Usage: instantiate this module for each downstream project, or use
# new-project.sh which creates the same resources via AWS CLI.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }

  statement {
    sid     = "SSODevelopers"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:sts::${var.aws_account_id}:assumed-role/AWSReservedSSO_*/*"]
    }
  }
}

resource "aws_iam_role" "project" {
  name               = "tf-${var.project_name}"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "S3ListBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.s3_bucket}"]
  }

  statement {
    sid     = "S3StateAccess"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket}/*"]
  }

  statement {
    sid     = "DynamoDBLocking"
    actions = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:*:${var.aws_account_id}:table/terraform-state"]
  }

  statement {
    sid     = "KMSDecrypt"
    actions = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "state_access" {
  name   = "tf-${var.project_name}-state-access"
  policy = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_role_policy_attachment" "state_access" {
  role       = aws_iam_role.project.name
  policy_arn = aws_iam_policy.state_access.arn
}
