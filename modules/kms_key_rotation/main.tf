locals {
  # Create a list of all environment-service combinations for key creation
  key_combinations = flatten([
    for env in var.environments : [
      for service in var.services : {
        environment = env
        service     = service
      }
    ]
  ])
  env_service_map = {
    for key_combo in local.key_combinations : "${key_combo.environment}-${key_combo.service}" => key_combo
  }
}

# Create KMS key for each environment and service
resource "aws_kms_key" "encryption_keys" {
  for_each = local.env_service_map
  
  description              = "Encryption key for ${each.value.service} in ${each.value.environment} environment"
  key_usage                = var.key_usage
  customer_master_key_spec = var.key_spec
  is_enabled               = true
  deletion_window_in_days  = 30
  enable_key_rotation      = var.import_key_material ? false : true
  

  # Key policy for least privilege
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-policy-${each.value.environment}-${each.value.service}",
    Statement = [
      {
        Sid       = "Enable IAM User Permissions",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "Allow Key Administration",
        Effect    = "Allow",
        Principal = {
          AWS = var.key_admin_role_arn != "" ? var.key_admin_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource  = "*"
      },
      {
        Sid       = "Allow Key Usage",
        Effect    = "Allow",
        Principal = {
          AWS = "*"
        },
        Action    = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource  = "*",
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Environment": each.value.environment,
            "aws:PrincipalTag/Service": each.value.service
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = each.value.environment
    Service     = each.value.service
    ManagedBy   = "Terraform"
  }
}

# Create key aliases for each key
resource "aws_kms_alias" "key_aliases" {
  for_each = local.env_service_map
  
  name          = "alias/${each.value.environment}-${each.value.service}"
  target_key_id = aws_kms_key.encryption_keys[each.key].key_id
}

# Get current account identity
data "aws_caller_identity" "current" {}


# Create null resources for key material import
resource "null_resource" "import_key_materials" {
  for_each = var.import_key_material ? local.env_service_map : {}

  triggers = {
    key_id = aws_kms_key.encryption_keys[each.key].id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/import_key_material.sh ${each.value.environment} ${each.value.service}"
    
    environment = {
      AWS_REGION     = var.region
      KEY_ID         = aws_kms_key.encryption_keys[each.key].id
      VALIDITY_DAYS  = var.key_material_validity_days
      KEY_MATERIAL_PATH = "${var.key_materials_base_path}/${each.value.environment}/${each.value.service}/key.bin"
    }
  }
}