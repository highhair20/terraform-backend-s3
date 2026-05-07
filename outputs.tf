output "aws_account_id" {
  description = "AWS account ID where backend resources are deployed"
  value       = var.aws_account_id
}

output "aws_region" {
  description = "AWS region where backend resources are deployed"
  value       = var.aws_region
}

output "github_org" {
  description = "GitHub organisation that owns downstream repos"
  value       = var.github_org
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.backend.bucket
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt state objects"
  value       = aws_kms_key.backend.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
