output "public_api_gateway_id" {
  description = "ID of the public API Gateway"
  value       = aws_api_gateway_rest_api.public_api.id
}

output "private_api_gateway_id" {
  description = "ID of the private API Gateway"
  value       = var.create_private_api ? aws_api_gateway_rest_api.private_api[0].id : null
}

output "public_api_gateway_url" {
  description = "URL of the public API Gateway"
  value       = length(var.public_api_routes) > 0 ? aws_api_gateway_deployment.public_deployment[0].invoke_url : null
}

output "private_api_gateway_url" {
  description = "URL of the private API Gateway"
  value       = var.create_private_api ? "${aws_api_gateway_deployment.private_deployment[0].invoke_url}" : null
}

output "api_domain_name" {
  description = "Custom domain name for the API"
  value       = var.certificate_arn != "" ? aws_api_gateway_domain_name.api_domain[0].domain_name : null
}

output "lambda_function_arns" {
  description = "ARNs of the Lambda functions"
  value       = var.lambda_functions
}

output "ecs_service_names" {
  description = "Names of the ECS services"
  value       = { for k, v in var.ecs_microservices : k => v.name }
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.waf_acl_arn
}
