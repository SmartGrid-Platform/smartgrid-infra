#################################################
# AWS SNS Topics (using official registry modules)
#################################################

module "sns_low_balance" {
  source  = "terraform-aws-modules/sns/aws"
  version = "~> 6.0"

  name = "smartgrid-${var.environment}-low-balance-alerts-${random_string.suffix.result}"
}

module "sns_disconnection" {
  source  = "terraform-aws-modules/sns/aws"
  version = "~> 6.0"

  name = "smartgrid-${var.environment}-disconnection-notices-${random_string.suffix.result}"
}

#################################################
# AWS Lambda Functions (using official registry modules)
#################################################

module "lambda_unit_calculator" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "smartgrid-${var.environment}-unit-calculator-${random_string.suffix.result}"
  description   = "Calculates units consumed from readings"
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  source_path = "${path.root}/../lambdas/unit_calculator"
  publish     = true

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:ap-south-1::*"
    }
  }
}

module "lambda_bill_generator" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "smartgrid-${var.environment}-bill-generator-${random_string.suffix.result}"
  description   = "Calculates billing amount based on units and rate"
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  source_path = "${path.root}/../lambdas/bill_generator"
  publish     = true

  environment_variables = {
    S3_BUCKET_NAME = aws_s3_bucket.bills_bucket.id
  }

  attach_policy_statements = true
  policy_statements = {
    s3 = {
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.bills_bucket.arn}/*"]
    }
  }
}

module "lambda_tariff_engine" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "smartgrid-${var.environment}-tariff-engine-${random_string.suffix.result}"
  description   = "Resolves active tariff rate"
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  source_path = "${path.root}/../lambdas/tariff_engine"
  publish     = true
}

resource "aws_sns_topic_subscription" "low_balance_email" {
  topic_arn = module.sns_low_balance.topic_arn
  protocol  = "email"
  endpoint  = "likhithabhogyam03@gmail.com"
}

resource "aws_sns_topic_subscription" "disconnection_email" {
  topic_arn = module.sns_disconnection.topic_arn
  protocol  = "email"
  endpoint  = "likhithabhogyam03@gmail.com"
}



