# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "backup-vault"
  kms_key_arn = aws_kms_key.backup.arn
  
  tags = {
    Purpose = "Automated backup"
  }
}

# KMS Key for backup encryption
resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Purpose = "Backup encryption"
  }
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "backup-plan"
  
  rule {
    rule_name         = "backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_frequency == "daily" ? "cron(0 1 * * ? *)" : var.backup_frequency == "weekly" ? "cron(0 1 ? * MON *)" : "cron(0 1 1 * ? *)"
    
    lifecycle {
      delete_after = var.backup_retention
    }
    
    # Cross-region copy
    dynamic "copy_action" {
      for_each = var.cross_region_enabled ? [1] : []
      
      content {
        destination_vault_arn = aws_backup_vault.cross_region[0].arn
        
        lifecycle {
          delete_after = var.backup_retention
        }
      }
    }
  }
  
  # Advanced backup settings
  advanced_backup_setting {
    resource_type = "EC2"
    backup_options = {
      WindowsVSS = "enabled"
    }
  }
  
  tags = {
    Purpose = "Automated backup"
  }
}

# Cross-region backup vault (if enabled)
resource "aws_backup_vault" "cross_region" {
  count = var.cross_region_enabled ? 1 : 0
  
  provider    = aws.cross_region
  name        = "cross-region-backup-vault"
  kms_key_arn = aws_kms_key.cross_region[0].arn
  
  tags = {
    Purpose = "Cross-region backup"
  }
}

# KMS Key for cross-region backup encryption
resource "aws_kms_key" "cross_region" {
  count = var.cross_region_enabled ? 1 : 0
  
  provider                = aws.cross_region
  description             = "KMS key for cross-region AWS Backup encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Purpose = "Cross-region backup encryption"
  }
}

# Resource selection with tag-based approach
resource "aws_backup_selection" "main" {
  name         = "tagged-resource-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id
  
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "ToBackup"
    value = "true"
  }
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "aws-backup-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })
}

# Attach necessary policies to the AWS Backup role
resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

# Cross-account backup configuration (if enabled)
resource "aws_backup_vault" "cross_account" {
  count = var.cross_account_enabled && var.cross_account_id != "" ? 1 : 0
  
  name = "cross-account-backup-vault"
  
  # KMS key from the target account should be provided
  kms_key_arn = "arn:aws:kms:${var.aws_region}:${var.cross_account_id}:key/${var.cross_account_kms_key_id}"
  
  tags = {
    Purpose = "Cross-account backup"
  }
}

# Vault Lock configuration for WORM protection
resource "aws_backup_vault_lock_configuration" "main" {
  count = var.worm_protection ? 1 : 0
  
  backup_vault_name   = aws_backup_vault.main.name
  changeable_for_days = 3  # Can be changed within 3 days, then becomes immutable
  max_retention_days  = 365
  min_retention_days  = 7
}

# AWS Backup Vault notifications
resource "aws_backup_vault_notifications" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  sns_topic_arn       = aws_sns_topic.backup_notifications.arn
  
  backup_vault_events = [
    "BACKUP_JOB_STARTED",
    "BACKUP_JOB_COMPLETED",
    "BACKUP_JOB_FAILED",
    "RESTORE_JOB_STARTED",
    "RESTORE_JOB_COMPLETED",
    "RESTORE_JOB_FAILED"
  ]
}

# SNS Topic for backup notifications
resource "aws_sns_topic" "backup_notifications" {
  name = "backup-notifications"
}

# AWS Backup Region
provider "aws" {
  alias  = "cross_region"
  region = var.cross_region_region
}

# Automatic recovery points cleanup
resource "aws_backup_vault_policy" "main" {
  backup_vault_name = aws_backup_vault.main.name
  
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "default",
    Statement = [
      {
        Sid       = "Allow account to use the backup vault",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = [
          "backup:CopyIntoBackupVault",
          "backup:StartBackupJob",
          "backup:GetRecoveryPointRestoreMetadata",
          "backup:DescribeBackupVault",
          "backup:DeleteRecoveryPoint",
          "backup:DeleteBackupVault",
          "backup:StartRestoreJob",
          "backup:PutBackupVaultNotifications",
          "backup:DeleteBackupVaultNotifications",
          "backup:ListRecoveryPointsByBackupVault"
        ],
        Resource  = "*"
      }
    ]
  })
}

# Get current account identity
data "aws_caller_identity" "current" {}
