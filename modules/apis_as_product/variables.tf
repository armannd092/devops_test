variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  
}
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
  
}

variable "create_private_api" {
  description = "Enable private API Gateway"
  type        = bool
  default     = false
  
}

variable "vpc_endpoint_ids" {
  description = "VPC endpoint IDs for private API Gateway"
  type        = list(string)
  default     = []
  
}

variable "create_vpc_endpoint" {
  description = "Enable VPC endpoint for private API Gateway"
  type        = bool
  default     = false
  
}

variable "vpc_id" {
  description = "VPC ID for private API Gateway"
  type        = string
  default     = ""
  
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for private API Gateway"
  type        = list(string)
  default     = []
  
}

variable "allowed_cidr_blocks" {
  description = "List of allowed CIDR blocks for private API Gateway"
  type        = list(string)
  default     = []
  
}

variable "create_private_dns" {
  description = "Enable private DNS for API Gateway"
  type        = bool
  default     = false
  
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for custom domain"
  type        = string
  default     = ""
  
}

variable "public_base_path" {
  description = "Base path for public API Gateway"
  type        = string
  default     = ""
  
}

variable "private_base_path" {
  description = "Base path for private API Gateway"
  type        = string
  default     = ""
  
}

variable "public_api_routes" {
  description = "Map of public API routes with their configurations"
  type        = map(object({
    http_method         = string
    path_part           = string
    parent_resource_id  = optional(string)
    integration_type    = string
    target_arn          = optional(string)
    target_url          = optional(string)
    vpc_link_id         = optional(string)
    authorization_type  = optional(string, "NONE")
    authorizer_id       = optional(string)
    api_key_required    = optional(bool, false)
  }))
  default     = {}
}

variable "stage_name" {
  description = "Stage name for the API Gateway"
  type        = string
  default     = "prod"
  
}

variable "private_api_routes" {
  description = "Map of private API routes with their configurations"
  type        = map(object({
    http_method         = string
    path_part           = string
    parent_resource_id  = optional(string)
    integration_type    = string
    target_arn          = optional(string)
    target_url          = optional(string)
    vpc_link_id         = optional(string)
    authorization_type  = optional(string, "NONE")
    authorizer_id       = optional(string)
    api_key_required    = optional(bool, false)
  }))
  default     = {}
}

variable "allowed_vpcs" {
  description = "List of allowed VPCs for private API Gateway"
  type        = list(string)
  default     = []
  
}

variable "cloudfront_secret_header" {
  description = "Secret header for CloudFront"
  type        = string
  default     = "value"
}
variable "domain_name" {
  description = "Domain name for the API endpoint"
  type        = string
}

variable "cf_price_class" {
  description = "Price class for CloudFront distribution"
  type        = string
  default     = "PriceClass_100"
}

variable "path_patterns" {
  description = "Path patterns for CloudFront cache behaviors"
  type        = list(object({
    path_pattern  = string
    target_origin = string
  }))
  default     = []
}

variable "waf_enabled" {
  description = "Enable AWS WAFv2"
  type        = bool
  default     = true
}

variable "waf_acl_arn" {
  description = "ARN of the WAF ACL to associate with the CloudFront distribution"
  type        = string
  default     = ""
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


