variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "The AWS profile to apply resources"
  type        = string
  default     = "personal"
}


variable "role_arn" {
  description = "ARN of the role to assume for cross-account deployment"
  type        = string
  default     = ""
}

# KMS Key Rotation Variables
variable "environments" {
  description = "List of environments for encryption keys (e.g., dev, test, prod)"
  type        = list(string)
  default     = ["dev", "int","prod"]
}

variable "services" {
  description = "List of services requiring encryption keys"
  type        = list(string)
  default     = ["s3", "rds", "ddb"]
}

variable "key_rotation_days" {
  description = "Number of days for automatic key rotation"
  type        = number
  default     = 60
}

variable "key_admin_role_arn" {
  description = "ARN of the role that manages the KMS keys"
  type        = string
  default     = ""
}

# APIs as Product Variables
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "allianz-trade-api"
}

variable "domain_name" {
  description = "Domain name for the API endpoint"
  type        = string
  default     = "api.allianz-trade.com"
}

variable "waf_enabled" {
  description = "Enable AWS WAFv2"
  type        = bool
  default     = true
}

variable "shield_advanced" {
  description = "Enable AWS Shield Advanced protection"
  type        = bool
  default     = true
}

variable "lambda_functions" {
  description = "Map of Lambda functions with their configurations"
  type        = map(object({
    name        = string
    runtime     = string
    handler     = string
    memory_size = number
    timeout     = number
  }))
  default     = {}
}

variable "ecs_microservices" {
  description = "Map of ECS microservices with their configurations"
  type        = map(object({
    name           = string
    container_port = number
    cpu            = number
    memory         = number
    desired_count  = number
  }))
  default     = {}
}

# Backup Policy Variables
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

variable "worm_protection" {
  description = "Enable WORM (Write Once Read Many) protection using Vault Lock"
  type        = bool
  default     = true
}
