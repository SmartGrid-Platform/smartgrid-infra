#################################################
# CloudWatch — Alarms, Dashboard, Container Insights
#################################################

# Allow EKS nodes to publish Container Insights metrics to CloudWatch
resource "aws_iam_role_policy_attachment" "eks_node_cloudwatch" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Container Insights addon — enables pod/node CPU & memory metrics in CloudWatch
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "amazon-cloudwatch-observability"

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_cloudwatch,
    aws_eks_node_group.nodes
  ]

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

#################################################
# RDS Alarms
#################################################

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "smartgrid-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization exceeded 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "smartgrid-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "RDS active connections exceeded 50"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "smartgrid-${var.environment}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2 GB in bytes
  alarm_description   = "RDS free storage dropped below 2 GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

#################################################
# ALB Alarms
#################################################

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "smartgrid-${var.environment}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB returned more than 10 5XX errors in 5 minutes"

  dimensions = {
    LoadBalancer = aws_lb.external_alb.arn_suffix
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "smartgrid-${var.environment}-alb-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB average target response time exceeded 2 seconds"

  dimensions = {
    LoadBalancer = aws_lb.external_alb.arn_suffix
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

#################################################
# Lambda Alarms (one per function)
#################################################

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    "unit-calculator" = module.lambda_unit_calculator.lambda_function_name
    "bill-generator"  = module.lambda_bill_generator.lambda_function_name
    "tariff-engine"   = module.lambda_tariff_engine.lambda_function_name
  }

  alarm_name          = "smartgrid-${var.environment}-lambda-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Lambda ${each.key} reported one or more errors"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = {
    "unit-calculator" = module.lambda_unit_calculator.lambda_function_name
    "bill-generator"  = module.lambda_bill_generator.lambda_function_name
    "tariff-engine"   = module.lambda_tariff_engine.lambda_function_name
  }

  alarm_name          = "smartgrid-${var.environment}-lambda-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_description   = "Lambda ${each.key} is being throttled"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

#################################################
# SQS DLQ Alarms — alert if messages pile up in dead letter queues
#################################################

resource "aws_cloudwatch_metric_alarm" "low_balance_dlq_depth" {
  alarm_name          = "smartgrid-${var.environment}-low-balance-dlq-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Messages in low-balance DLQ — delivery failed after 3 retries"

  dimensions = {
    QueueName = aws_sqs_queue.low_balance_dlq.name
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_cloudwatch_metric_alarm" "disconnection_dlq_depth" {
  alarm_name          = "smartgrid-${var.environment}-disconnection-dlq-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Messages in disconnection DLQ — delivery failed after 3 retries"

  dimensions = {
    QueueName = aws_sqs_queue.disconnection_dlq.name
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

#################################################
# CloudWatch Dashboard — Single-pane overview
#################################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "smartgrid-${var.environment}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS — CPU & Connections"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.database.identifier, { label = "CPU %" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.database.identifier, { yAxis = "right", label = "Connections" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS — Free Storage Space"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.database.identifier, { label = "Free Storage (bytes)" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB — Requests & 5XX Errors"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.external_alb.arn_suffix, { label = "Requests" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.external_alb.arn_suffix, { yAxis = "right", label = "5XX Errors" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB — Target Response Time"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.external_alb.arn_suffix, { label = "Avg Response Time (s)" }]
          ]
          period = 60
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Lambda — Invocations & Errors"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda_unit_calculator.lambda_function_name, { label = "UnitCalc Invocations" }],
            ["AWS/Lambda", "Errors", "FunctionName", module.lambda_unit_calculator.lambda_function_name, { label = "UnitCalc Errors" }],
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda_bill_generator.lambda_function_name, { label = "BillGen Invocations" }],
            ["AWS/Lambda", "Errors", "FunctionName", module.lambda_bill_generator.lambda_function_name, { label = "BillGen Errors" }],
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda_tariff_engine.lambda_function_name, { label = "Tariff Invocations" }],
            ["AWS/Lambda", "Errors", "FunctionName", module.lambda_tariff_engine.lambda_function_name, { label = "Tariff Errors" }]
          ]
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "SQS — Queue Depth & DLQ Messages"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.low_balance.name, { label = "LowBalance Queue" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.disconnection.name, { label = "Disconnection Queue" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.low_balance_dlq.name, { label = "LowBalance DLQ" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.disconnection_dlq.name, { label = "Disconnection DLQ" }]
          ]
          period = 300
          region = var.aws_region
        }
      }
    ]
  })
}
