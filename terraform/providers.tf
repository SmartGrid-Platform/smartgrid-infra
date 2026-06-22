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

  backend "s3" {
    bucket         = "smartgrid-tf-state-06vasp"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "smartgrid-tf-locks-06vasp"
  }
}

provider "aws" {
  region = var.aws_region
}

# Secondary provider for WAF in us-east-1 (CloudFront requirement)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
