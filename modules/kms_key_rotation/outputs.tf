output "kms_key_arns" {
  description = "ARNs of the created KMS keys"
  value       = { for k, v in aws_kms_key.encryption_keys : k => v.arn }
}

output "kms_key_aliases" {
  description = "Aliases of the created KMS keys"
  value       = { for k, v in aws_kms_alias.key_aliases : k => v.name }
}

output "rotation_script_path" {
  description = "Path to the key rotation script"
  value       = "${path.module}/scripts/rotate_external_key.sh"
}