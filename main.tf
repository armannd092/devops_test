terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  backend "s3" {
    bucket         = "tfstate-allianz-trade"
    key            = "terraform.tfstate"
    region         = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
  # For multi-account setup
  assume_role {
    role_arn = var.role_arn != "" ? var.role_arn : null
  }
}

# Include the different scenarios
module "kms_key_rotation" {
  source = "./modules/kms_key_rotation"
  
  environments       = var.environments
  services           = var.services
  key_rotation_days  = var.key_rotation_days
  key_admin_role_arn = var.key_admin_role_arn
  import_key_material = true
}

module "apis_as_product" {
  source = "./modules/apis_as_product"
  
  api_name             = var.api_name
  domain_name          = var.domain_name
  waf_enabled          = var.waf_enabled
  shield_advanced      = var.shield_advanced
  lambda_functions     = var.lambda_functions
  ecs_microservices    = var.ecs_microservices
}

module "backup_policy" {
  source = "./modules/backup_policy"
  
  backup_frequency     = var.backup_frequency
  backup_retention     = var.backup_retention
  cross_region_enabled = var.cross_region_enabled
  cross_region_region  = var.cross_region_region
  cross_account_enabled = var.cross_account_enabled
  cross_account_id     = var.cross_account_id
  worm_protection      = var.worm_protection
}
