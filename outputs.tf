output "s3_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.backend.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for state locking"
  value       = aws_dynamodb_table.terraform_state.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt state objects"
  value       = aws_kms_key.backend.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
