resource "aws_s3_bucket" "backend" {
  bucket = "${var.bucket_name}"
  object_lock_enabled = true
  tags = {
    Name = "${var.bucket_name}"
  }
}
# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "backend" {
  bucket = aws_s3_bucket.backend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_acl" "backend" {
  bucket = aws_s3_bucket.backend.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.backend]
}
resource "aws_s3_bucket_versioning" "backend" {
  bucket = aws_s3_bucket.backend.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_kms_key" "backend" {
  description             = "This key is used to encrypt terraform bucket objects"
  deletion_window_in_days = 10
}
resource "aws_s3_bucket_server_side_encryption_configuration" "backend" {
  bucket = aws_s3_bucket.backend.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backend.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
