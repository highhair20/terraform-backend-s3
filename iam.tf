# ---------------------------------------------------------------------------
# IAM User
# tf-svc-user is the service identity used by all downstream Terraform
# projects to read and write state. It assumes a project-specific role
# to obtain the permissions needed for each project.
# ---------------------------------------------------------------------------
resource "aws_iam_user" "tf_svc_user" {
  name = "tf-svc-user"
}

# ---------------------------------------------------------------------------
# State access policy (attached to tf-svc-user)
# Grants the minimum permissions needed to read/write state and acquire
# DynamoDB locks during normal terraform plan/apply operations.
# ---------------------------------------------------------------------------
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
    resources = ["arn:aws:dynamodb:*:${var.aws_account_id}:table/terraform_state"]
  }

  statement {
    sid     = "KMSDecrypt"
    actions = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.backend.arn]
  }
}

resource "aws_iam_policy" "state_access" {
  name        = "tf-svc-policy-state"
  description = "Allows tf-svc-user to read and write Terraform state in S3 and acquire DynamoDB locks"
  policy      = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_user_policy_attachment" "state_access" {
  user       = aws_iam_user.tf_svc_user.name
  policy_arn = aws_iam_policy.state_access.arn
}

# ---------------------------------------------------------------------------
# IAM Role (tf-svc-role-state)
# Assumed by tf-svc-user when provisioning the backend resources themselves.
# Separates runtime state access from infrastructure provisioning permissions.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "tf_svc_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.tf_svc_user.arn]
    }
  }
}

resource "aws_iam_role" "tf_svc_role_state" {
  name               = "tf-svc-role-state"
  assume_role_policy = data.aws_iam_policy_document.tf_svc_role_trust.json
}

# ---------------------------------------------------------------------------
# Provisioning policy (attached to tf-svc-role-state)
# Grants permissions to create and manage the backend S3 bucket, DynamoDB
# table, and KMS key. Only used during bootstrap — not during normal runs.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "state_provisioning" {
  statement {
    sid = "DynamoDB"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:TagResource",
    ]
    resources = ["arn:aws:dynamodb:*:${var.aws_account_id}:table/terraform_state"]
  }

  statement {
    sid = "S3"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
      "s3:PutBucketAcl",
      "s3:PutBucketObjectLockConfiguration",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
    ]
    resources = ["arn:aws:s3:::${var.s3_bucket}"]
  }

  statement {
    sid = "KMSManage"
    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:ScheduleKeyDeletion",
    ]
    resources = ["arn:aws:kms:*:${var.aws_account_id}:key/*"]
  }

  statement {
    sid       = "KMSCreate"
    actions   = ["kms:CreateKey"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "state_provisioning" {
  name        = "tf-svc-policy-state-provisioning"
  description = "Allows tf-svc-role-state to create and manage the Terraform remote backend resources"
  policy      = data.aws_iam_policy_document.state_provisioning.json
}

resource "aws_iam_role_policy_attachment" "state_provisioning" {
  role       = aws_iam_role.tf_svc_role_state.name
  policy_arn = aws_iam_policy.state_provisioning.arn
}
