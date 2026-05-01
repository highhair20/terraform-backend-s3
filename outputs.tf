output "s3_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.backend.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for state locking"
  value       = aws_dynamodb_table.terraform-lock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt state objects"
  value       = aws_kms_key.backend.arn
}

output "tf_svc_user_arn" {
  description = "ARN of the IAM service user used by downstream Terraform projects"
  value       = aws_iam_user.tf_svc_user.arn
}

output "tf_svc_role_arn" {
  description = "ARN of the IAM role assumed by tf-svc-user when provisioning backend resources"
  value       = aws_iam_role.tf_svc_role_state.arn
}
