#################################################
# SQS — Message Queuing (SNS fan-out buffer)
# Pattern: SNS Topic → SQS Queue → (future Lambda processor)
# Adds retry logic and dead-lettering on top of direct SNS email
#################################################

# Dead Letter Queues — messages land here after 3 failed delivery attempts
resource "aws_sqs_queue" "low_balance_dlq" {
  name                      = "smartgrid-${var.environment}-low-balance-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_sqs_queue" "disconnection_dlq" {
  name                      = "smartgrid-${var.environment}-disconnection-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

# Main Queues
resource "aws_sqs_queue" "low_balance" {
  name                       = "smartgrid-${var.environment}-low-balance-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.low_balance_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_sqs_queue" "disconnection" {
  name                       = "smartgrid-${var.environment}-disconnection-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.disconnection_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

# Queue Policies — allow SNS to send messages to these queues
resource "aws_sqs_queue_policy" "low_balance" {
  queue_url = aws_sqs_queue.low_balance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.low_balance.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = module.sns_low_balance.topic_arn
        }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "disconnection" {
  queue_url = aws_sqs_queue.disconnection.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.disconnection.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = module.sns_disconnection.topic_arn
        }
      }
    }]
  })
}

# SNS → SQS subscriptions
resource "aws_sns_topic_subscription" "low_balance_to_sqs" {
  topic_arn = module.sns_low_balance.topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.low_balance.arn
}

resource "aws_sns_topic_subscription" "disconnection_to_sqs" {
  topic_arn = module.sns_disconnection.topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.disconnection.arn
}
