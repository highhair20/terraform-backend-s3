resource "aws_s3_bucket" "backend" {
  bucket = var.s3_bucket

  # object_lock_enabled = true  # uncomment for WORM compliance; requires bucket recreation

  tags = {
    Name = var.s3_bucket
  }
}

resource "aws_s3_bucket_ownership_controls" "backend" {
  bucket = aws_s3_bucket.backend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "backend" {
  bucket = aws_s3_bucket.backend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backend" {
  bucket = aws_s3_bucket.backend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "backend" {
  description             = "Encrypts Terraform state objects in S3"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "terraform-backend"
  }
}

resource "aws_kms_alias" "backend" {
  name          = "alias/terraform-backend"
  target_key_id = aws_kms_key.backend.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend" {
  bucket = aws_s3_bucket.backend.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backend.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backend" {
  bucket     = aws_s3_bucket.backend.id
  depends_on = [aws_s3_bucket_versioning.backend]

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
