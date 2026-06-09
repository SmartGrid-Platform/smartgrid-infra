#################################################
# S3 Frontend Bucket & Access Control
#################################################

resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "smartgrid-${var.environment}-frontend-bucket-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name        = "smartgrid-${var.environment}-frontend-bucket"
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_pab" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "smartgrid-${var.environment}-oac-${random_string.suffix.result}"
  description                       = "OAC for SmartGrid static frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

#################################################
# WAFv2 Configuration (CloudFront Scope)
#################################################

resource "aws_wafv2_web_acl" "cdn_waf" {
  provider    = aws.us_east_1
  name        = "smartgrid-${var.environment}-cdn-waf-${random_string.suffix.result}"
  description = "WAF protection for SmartGrid CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "smartgrid-${var.environment}-cdn-waf-metric"
    sampled_requests_enabled   = false
  }

  # Rate limiting rule to prevent brute-forcing/DDoS
  rule {
    name     = "IPRateLimit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "IPRateLimitMetric"
      sampled_requests_enabled   = false
    }
  }
}

#################################################
# CloudFront CDN Distribution
#################################################

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.cdn_waf.arn

  # Origin 1: S3 static frontend files
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "S3-Frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Origin 2: Public ALB for microservices APIs
  origin {
    domain_name = aws_lb.external_alb.dns_name
    origin_id   = "ALB-API"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  # Default Cache Behavior: Serve frontend assets from S3
  default_cache_behavior {
    target_origin_id       = "S3-Frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
    compress    = true
  }

  # Ordered Cache Behavior: Route API traffic to the ALB
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "ALB-API"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Host", "Origin", "Referer"]
      cookies {
        forward = "all"
      }
    }

    # API responses must never be cached
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Redirect SPA routes to index.html so React Router handles pages correctly
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "smartgrid-${var.environment}-cloudfront"
    Environment = "production"
  }
}


