output "role_arn" {
  description = "ARN of the IAM role for use in GitHub Actions workflows and local dev tfvars"
  value       = aws_iam_role.project.arn
}
