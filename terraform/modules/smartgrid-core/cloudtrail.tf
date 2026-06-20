#################################################
# CloudTrail — Audit Logging
#################################################

# S3 bucket to store CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "smartgrid-${var.environment}-cloudtrail-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name        = "smartgrid-${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail requires a specific bucket policy to allow the service to write logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]
}

# CloudWatch Log Group to stream CloudTrail events for querying
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/smartgrid-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "smartgrid-${var.environment}-cloudtrail-cw"
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

# IAM role allowing CloudTrail to write to the CloudWatch Log Group
resource "aws_iam_role" "cloudtrail_cw_role" {
  name = "smartgrid-${var.environment}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw_policy" {
  name = "cloudtrail-cw-write"
  role = aws_iam_role.cloudtrail_cw_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# CloudTrail — multi-region trail covering all API calls
resource "aws_cloudtrail" "main" {
  name                          = "smartgrid-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw_role.arn

  tags = {
    Name        = "smartgrid-${var.environment}-trail"
    Environment = var.environment
    Owner       = "smartgrid-team"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}
