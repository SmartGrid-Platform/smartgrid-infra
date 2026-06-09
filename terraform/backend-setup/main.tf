provider "aws" {
  region = "ap-south-1"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "smartgrid-tf-state-${random_string.suffix.result}"
  force_destroy = true # Only for this exercise, usually false for state buckets

  tags = {
    Name        = "SmartGrid Terraform State"
    Environment = "Global"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "smartgrid-tf-locks-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "SmartGrid Terraform State Locks"
    Environment = "Global"
  }
}

output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "The name of the S3 bucket to store Terraform state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The name of the DynamoDB table for state locking"
}
