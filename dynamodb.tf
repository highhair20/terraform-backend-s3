/*
  The primary key used to lock Terraform state in DynamoDB must be named
  LockID and must be a string type (S).
*/
resource "aws_dynamodb_table" "terraform_state" {
  name         = "terraform-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}
