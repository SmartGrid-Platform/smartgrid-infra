#################################################
# Secrets Manager — single source of runtime truth
#
# Every value comes from a Terraform variable.
# Sensitive vars are set via TF_VAR_* env vars (GitHub Secrets).
# Non-sensitive vars have defaults in variables.tf that can be
# overridden with TF_VAR_* env vars or terraform.tfvars.
#################################################

resource "aws_secretsmanager_secret" "smartgrid_secret" {
  name                    = "smartgrid-${var.environment}/config"
  description             = "Runtime configuration for SmartGrid microservices"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "smartgrid_secret_val" {
  secret_id = aws_secretsmanager_secret.smartgrid_secret.id

  secret_string = jsonencode({
    # ── Database ───────────────────────────────
    DB_HOST     = aws_db_instance.database.address
    DB_PORT     = tostring(var.db_port)
    DB_NAME     = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password

    # ── Auth ───────────────────────────────────
    JWT_SECRET = var.jwt_secret

    # ── Admin Bootstrap ────────────────────────
    ADMIN_NAME     = var.admin_name
    ADMIN_EMAIL    = var.admin_email
    ADMIN_PASSWORD = var.admin_password

    # ── AWS / Infrastructure ───────────────────
    AWS_REGION     = var.aws_region
    S3_BUCKET_NAME = aws_s3_bucket.bills_bucket.id

    # ── Lambda ─────────────────────────────────
    LAMBDA_UNIT_CALCULATOR = module.lambda_unit_calculator.lambda_function_name
    LAMBDA_BILL_GENERATOR  = module.lambda_bill_generator.lambda_function_name
    LAMBDA_TARIFF_ENGINE   = module.lambda_tariff_engine.lambda_function_name

    # ── Messaging ──────────────────────────────
    SNS_LOW_BALANCE_ARN       = module.sns_low_balance.topic_arn
    SNS_DISCONNECTION_ARN     = module.sns_disconnection.topic_arn
    SQS_LOW_BALANCE_URL       = aws_sqs_queue.low_balance.url
    SQS_DISCONNECTION_URL     = aws_sqs_queue.disconnection.url
    SQS_LOW_BALANCE_DLQ_URL   = aws_sqs_queue.low_balance_dlq.url
    SQS_DISCONNECTION_DLQ_URL = aws_sqs_queue.disconnection_dlq.url

    # ── AI / Bedrock ───────────────────────────
    BEDROCK_MODEL_PRIMARY  = var.bedrock_primary_model
    BEDROCK_MODEL_FALLBACK = var.bedrock_fallback_model

    # ── Email (SMTP) ───────────────────────────
    SMTP_HOST    = var.smtp_host
    SMTP_PORT    = var.smtp_port
    SMTP_USER    = var.smtp_user
    SMTP_PASS    = var.smtp_pass
    SENDER_EMAIL = var.sender_email

    # ── Kubernetes ─────────────────────────────
    K8S_NAMESPACE = var.k8s_namespace
  })
}
