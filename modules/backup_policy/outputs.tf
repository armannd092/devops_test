output "backup_vault_arn" {
  description = "ARN of the main backup vault"
  value       = aws_backup_vault.main.arn
}

output "backup_plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.main.arn
}

output "cross_region_vault_arn" {
  description = "ARN of the cross-region backup vault"
  value       = var.cross_region_enabled ? aws_backup_vault.cross_region[0].arn : null
}

output "cross_account_vault_arn" {
  description = "ARN of the cross-account backup vault"
  value       = var.cross_account_enabled && var.cross_account_id != "" ? aws_backup_vault.cross_account[0].arn : null
}

output "backup_role_arn" {
  description = "ARN of the IAM role for AWS Backup"
  value       = aws_iam_role.backup.arn
}
