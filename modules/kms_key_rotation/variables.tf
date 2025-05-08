variable "region" {
  description = "AWS region for the KMS keys"
  type        = string
  default     = "us-east-1"
  
}

variable "environments" {
  description = "List of environments for encryption keys (e.g., dev, prod)"
  type        = list(string)
}

variable "services" {
  description = "List of services requiring encryption keys"
  type        = list(string)
}

variable "key_rotation_days" {
  description = "Number of days for automatic key rotation"
  type        = number
  default     = 60
}

variable "key_usage" {
  description = "Key usage type (e.g., ENCRYPT_DECRYPT, SIGN_VERIFY)"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "key_spec" {
  description = "Key specification (e.g., SYMMETRIC_DEFAULT, RSA_2048)"
  type        = string
  default     = "RSA_2048"
  
}

variable "key_admin_role_arn" {
  description = "ARN of the role that manages the KMS keys"
  type        = string
  default     = ""
}

variable "import_key_material" {
  description = "Whether to import key material using the provisioner"
  type        = bool
  default     = false
}

variable "key_material_validity_days" {
  description = "Validity period for the imported key material in days"
  type        = number
  default     = 365
}

variable "key_materials_base_path" {
  description = "Base path for key materials, organized by environment and service"
  type        = string
  default     = "./local/keys"
}