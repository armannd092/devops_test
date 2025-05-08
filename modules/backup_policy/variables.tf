variable "backup_frequency" {
  description = "Frequency of backup (e.g., daily, weekly, monthly)"
  type        = string
  default     = "daily"
}

variable "backup_retention" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "cross_region_enabled" {
  description = "Enable cross-region backup"
  type        = bool
  default     = true
}

variable "cross_region_region" {
  description = "Target region for cross-region backup"
  type        = string
  default     = "eu-west-1"
}

variable "cross_account_enabled" {
  description = "Enable cross-account backup"
  type        = bool
  default     = true
}

variable "cross_account_id" {
  description = "Target account ID for cross-account backup"
  type        = string
  default     = ""
}

variable "cross_account_kms_key_id" {
  description = "KMS key ID in the target account for cross-account backup"
  type        = string
  default     = ""
}

variable "worm_protection" {
  description = "Enable WORM (Write Once Read Many) protection using Vault Lock"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
