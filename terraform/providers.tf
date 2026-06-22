terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  # Backend is configured in backend.tf via -backend-config flags in CI.
  # Run: cd terraform/backend-setup && terraform apply
  # to create the S3 bucket and DynamoDB table first.
}

provider "aws" {
  region = var.aws_region
}

# Secondary provider for WAF (CloudFront WAF ACLs must live in us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
