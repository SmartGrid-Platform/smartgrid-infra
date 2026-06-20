#################################################
# AWS Backup — Centralized RDS Backup
#################################################

resource "aws_iam_role" "backup_role" {
  name = "smartgrid-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "main" {
  name = "smartgrid-${var.environment}-backup-vault"

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

resource "aws_backup_plan" "main" {
  name = "smartgrid-${var.environment}-backup-plan"

  # Daily backup at 2 AM UTC — retained for 7 days
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"

    lifecycle {
      delete_after = 7
    }
  }

  # Weekly backup every Sunday at 3 AM UTC — retained for 4 weeks
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * SUN *)"

    lifecycle {
      delete_after = 28
    }
  }

  tags = {
    Environment = var.environment
    Owner       = "smartgrid-team"
  }
}

# Backup selection targets the RDS instance directly by ARN
resource "aws_backup_selection" "rds" {
  name         = "smartgrid-rds-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.main.id

  resources = [
    aws_db_instance.database.arn
  ]
}
