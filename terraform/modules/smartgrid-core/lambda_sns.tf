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

  function_name          = "smartgrid-${var.environment}-unit-calculator-${random_string.suffix.result}"
  description            = "Calculates units consumed from readings"
  handler                = "index.handler"
  runtime                = "nodejs18.x"
  local_existing_package = "${path.root}/../lambdas/zips/unit_calculator.zip"
  create_package         = false
  publish                = true

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    }
  }
}

module "lambda_bill_generator" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name          = "smartgrid-${var.environment}-bill-generator-${random_string.suffix.result}"
  description            = "Calculates billing amount based on units and rate"
  handler                = "index.handler"
  runtime                = "nodejs18.x"
  local_existing_package = "${path.root}/../lambdas/zips/bill_generator.zip"
  create_package         = false
  publish                = true

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
    kms = {
      effect    = "Allow"
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = [aws_kms_key.s3_key.arn]
    }
  }
}

module "lambda_tariff_engine" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name          = "smartgrid-${var.environment}-tariff-engine-${random_string.suffix.result}"
  description            = "Resolves active tariff rate"
  handler                = "index.handler"
  runtime                = "nodejs18.x"
  local_existing_package = "${path.root}/../lambdas/zips/tariff_engine.zip"
  create_package         = false
  publish                = true
}

# SNS email subscriptions — only created when notification_email is set
resource "aws_sns_topic_subscription" "low_balance_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = module.sns_low_balance.topic_arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "disconnection_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = module.sns_disconnection.topic_arn
  protocol  = "email"
  endpoint  = var.notification_email
}
