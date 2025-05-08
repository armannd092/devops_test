#-------------------------------------------------------------------------
# Public API Gateway for External Consumption
#-------------------------------------------------------------------------


resource "aws_api_gateway_rest_api" "public_api" {
  name        = "${var.api_name}-public"
  description = "API Gateway for Allianz Trade APIs"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-public"
      Type = "Public"
    }
  )

    # Resource policy to enforce CloudFront origin validation
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "execute-api:Invoke",
        Resource = "execute-api:/*",
        Condition = {
          StringEquals = {
            "aws:referer": var.cloudfront_secret_header
          }
        }
      },
      {
        Effect = "Deny",
        Principal = "*",
        Action = "execute-api:Invoke",
        Resource = "execute-api:/*",
        Condition = {
          StringNotEquals = {
            "aws:referer": var.cloudfront_secret_header
          }
        }
      }
    ]
  })
}

#-------------------------------------------------------------------------
# Private API Gateway for Internal Consumption
#-------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "private_api" {
  count       = var.create_private_api ? 1 : 0
  name        = "${var.api_name}-private"
  description = "Private API Gateway for internal services"
  
  endpoint_configuration {
    types          = ["PRIVATE"]
    vpc_endpoint_ids = var.vpc_endpoint_ids
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-private"
      Type = "Private"
    }
  )
  
  # Resource policy to restrict to VPC endpoints
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = "*",
      Action    = "execute-api:Invoke",
      Resource  = "execute-api:/*",
      Condition = {
        StringEquals = {
          "aws:SourceVpc": var.allowed_vpcs
        }
      }
    }]
  })
}

#-------------------------------------------------------------------------
# VPC Endpoint for Private API Gateway Access
#-------------------------------------------------------------------------

resource "aws_vpc_endpoint" "api_gateway" {
  count              = var.create_vpc_endpoint ? 1 : 0
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.api_endpoint[0].id]
  private_dns_enabled = true
  
  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-vpc-endpoint"
    }
  )
}

resource "aws_security_group" "api_endpoint" {
  count       = var.create_vpc_endpoint ? 1 : 0
  name        = "${var.api_name}-apigw-endpoint-sg"
  description = "Security group for API Gateway VPC Endpoint"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-apigw-endpoint-sg"
    }
  )
}


#-------------------------------------------------------------------------
# Route53 Private Hosted Zone for Internal API Resolution
#-------------------------------------------------------------------------
resource "aws_route53_zone" "private" {
  count = var.create_private_dns ? 1 : 0
  name  = var.domain_name
  
  vpc {
    vpc_id = var.vpc_id
  }
  
  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-private-zone"
    }
  )
}

resource "aws_route53_record" "private_api" {
  count   = var.create_private_dns ? 1 : 0
  zone_id = aws_route53_zone.private[0].zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = aws_vpc_endpoint.api_gateway[0].dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.api_gateway[0].dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}



#-------------------------------------------------------------------------
# Public Custom Domain Name
#-------------------------------------------------------------------------
resource "aws_api_gateway_domain_name" "api_domain" {
  count                   = var.certificate_arn != "" ? 1 : 0
  domain_name              = var.domain_name
  regional_certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# Public API Mapping
resource "aws_api_gateway_base_path_mapping" "public_api_mapping" {
  count       = var.certificate_arn != "" && length(var.public_api_routes) > 0 ? 1 : 0
  api_id      = aws_api_gateway_rest_api.public_api.id
  stage_name  = length(var.public_api_routes) > 0 ? aws_api_gateway_stage.public_stage[0].stage_name : ""
  domain_name = aws_api_gateway_domain_name.api_domain[0].domain_name
  base_path   = var.public_base_path
}

# Private API Mapping (if applicable)
resource "aws_api_gateway_base_path_mapping" "private_api_mapping" {
  count       = var.create_private_api && var.certificate_arn != "" ? 1 : 0
  api_id      = aws_api_gateway_rest_api.private_api[0].id
  stage_name  = aws_api_gateway_stage.private_stage[0].stage_name
  domain_name = aws_api_gateway_domain_name.api_domain[0].domain_name
  base_path   = var.private_base_path
}


#-------------------------------------------------------------------------
# Public API Deployment & Stage
#-------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "public_deployment" {
  count = length(var.public_api_routes) > 0 ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.public_api.id

  triggers = {
    redeployment = sha1(jsonencode({
      routes = var.public_api_routes
      # Add other elements that should trigger redeployment
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.public_methods,
    aws_api_gateway_integration.public_lambda_integrations,
    aws_api_gateway_integration.public_alb_integrations
  ]
}

resource "aws_api_gateway_stage" "public_stage" {
  count = length(var.public_api_routes) > 0 ? 1 : 0
  deployment_id = aws_api_gateway_deployment.public_deployment[0].id
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  stage_name    = var.stage_name

  tags = merge(
    var.tags,
    {
      Type = "Public"
    }
  )
}

#-------------------------------------------------------------------------
# Private API Deployment & Stage
#-------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "private_deployment" {
  count       = var.create_private_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.private_api[0].id

  triggers = {
    redeployment = sha1(jsonencode({
      routes = var.private_api_routes
      # Add other elements that should trigger redeployment
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.private_methods,
    aws_api_gateway_integration.private_lambda_integrations,
    aws_api_gateway_integration.private_alb_integrations
  ]
}

resource "aws_api_gateway_stage" "private_stage" {
  count         = var.create_private_api ? 1 : 0
  deployment_id = aws_api_gateway_deployment.private_deployment[0].id
  rest_api_id   = aws_api_gateway_rest_api.private_api[0].id
  stage_name    = var.stage_name

  tags = merge(
    var.tags,
    {
      Type = "Private"
    }
  )
}

#-------------------------------------------------------------------------
# CloudFront Distribution with Path-Based Routing
#-------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "api_distribution" {
  enabled             = true
  aliases             = [var.domain_name]
  default_root_object = ""
  price_class         = var.cf_price_class
  
  # Public API Gateway origin
  origin {
    domain_name = "${aws_api_gateway_rest_api.public_api.id}.execute-api.${var.region}.amazonaws.com"
    origin_id   = "public-api"
    origin_path = length(var.public_api_routes) > 0 ? "/${aws_api_gateway_stage.public_stage[0].stage_name}" : "/prod"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    
    # Secret header to validate CloudFront as the source
    custom_header {
      name  = "Referer"
      value = var.cloudfront_secret_header
    }
  }
  
  # Dynamic path patterns for routing to public API
  dynamic "ordered_cache_behavior" {
    for_each = var.path_patterns
    
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = ordered_cache_behavior.value.target_origin
      
      forwarded_values {
        query_string = true
        headers      = ["Authorization", "Host"]
        cookies {
          forward = "all"
        }
      }
      
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    }
  }
  
  # Default behavior (public API Gateway)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "public-api"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Host"]
      cookies {
        forward = "all"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  
  # SSL configuration
  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn != "" ? var.certificate_arn : null
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
    ssl_support_method       = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version = var.certificate_arn != "" ? "TLSv1.2_2021" : null
  }
  
  # Geo restriction settings (optional)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  # WAF association
  web_acl_id = var.waf_enabled ? var.waf_acl_arn : null
  
  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-distribution"
    }
  )
}

#-------------------------------------------------------------------------
# Shield Advanced Protection
#-------------------------------------------------------------------------
resource "aws_shield_protection" "api_shield" {
  count        = var.shield_advanced ? 1 : 0
  name         = "${var.api_name}-protection"
  resource_arn = aws_cloudfront_distribution.api_distribution.arn
}

resource "aws_shield_protection" "api_regional_shield" {
  count        = var.shield_advanced && length(var.public_api_routes) > 0 ? 1 : 0
  name         = "${var.api_name}-regional-protection"
  resource_arn = aws_api_gateway_stage.public_stage[0].arn
}

#-------------------------------------------------------------------------
# Public API Resources, Methods, and Integrations
#-------------------------------------------------------------------------
resource "aws_api_gateway_resource" "public_resources" {
  for_each    = var.public_api_routes
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  parent_id   = each.value.parent_resource_id != null ? each.value.parent_resource_id : aws_api_gateway_rest_api.public_api.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_method" "public_methods" {
  for_each      = var.public_api_routes
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  resource_id   = aws_api_gateway_resource.public_resources[each.key].id
  http_method   = each.value.http_method
  authorization = each.value.authorization_type
  authorizer_id = each.value.authorizer_id
  api_key_required = each.value.api_key_required
}

resource "aws_api_gateway_integration" "public_lambda_integrations" {
  for_each                = { for k, v in var.public_api_routes : k => v if v.integration_type == "LAMBDA" }
  rest_api_id             = aws_api_gateway_rest_api.public_api.id
  resource_id             = aws_api_gateway_resource.public_resources[each.key].id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${each.value.target_arn}/invocations"
}

resource "aws_api_gateway_integration" "public_alb_integrations" {
  for_each          = { for k, v in var.public_api_routes : k => v if v.integration_type == "HTTP" }
  rest_api_id       = aws_api_gateway_rest_api.public_api.id
  resource_id       = aws_api_gateway_resource.public_resources[each.key].id
  http_method       = each.value.http_method
  type              = "HTTP_PROXY"
  integration_http_method = each.value.http_method
  uri               = each.value.target_url
  connection_type   = "VPC_LINK"
  connection_id     = each.value.vpc_link_id
}

resource "aws_lambda_permission" "public_lambda_permissions" {
  for_each      = { for k, v in var.public_api_routes : k => v if v.integration_type == "LAMBDA" }
  statement_id  = "AllowExecutionFromPublicAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.target_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.public_api.execution_arn}/*/${each.value.http_method}${aws_api_gateway_resource.public_resources[each.key].path}"
}

#-------------------------------------------------------------------------
# Private API Resources, Methods, and Integrations (if applicable)
#-------------------------------------------------------------------------
resource "aws_api_gateway_resource" "private_resources" {
  for_each    = var.create_private_api ? var.private_api_routes : {}
  rest_api_id = aws_api_gateway_rest_api.private_api[0].id
  parent_id   = each.value.parent_resource_id != null ? each.value.parent_resource_id : aws_api_gateway_rest_api.private_api[0].root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_method" "private_methods" {
  for_each      = var.create_private_api ? var.private_api_routes : {}
  rest_api_id   = aws_api_gateway_rest_api.private_api[0].id
  resource_id   = aws_api_gateway_resource.private_resources[each.key].id
  http_method   = each.value.http_method
  authorization = each.value.authorization_type
  authorizer_id = each.value.authorizer_id
  api_key_required = each.value.api_key_required
}

resource "aws_api_gateway_integration" "private_lambda_integrations" {
  for_each                = var.create_private_api ? { for k, v in var.private_api_routes : k => v if v.integration_type == "LAMBDA" } : {}
  rest_api_id             = aws_api_gateway_rest_api.private_api[0].id
  resource_id             = aws_api_gateway_resource.private_resources[each.key].id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${each.value.target_arn}/invocations"
}

resource "aws_api_gateway_integration" "private_alb_integrations" {
  for_each          = var.create_private_api ? { for k, v in var.private_api_routes : k => v if v.integration_type == "HTTP" } : {}
  rest_api_id       = aws_api_gateway_rest_api.private_api[0].id
  resource_id       = aws_api_gateway_resource.private_resources[each.key].id
  http_method       = each.value.http_method
  type              = "HTTP_PROXY"
  integration_http_method = each.value.http_method
  uri               = each.value.target_url
  connection_type   = "VPC_LINK"
  connection_id     = each.value.vpc_link_id
}

resource "aws_lambda_permission" "private_lambda_permissions" {
  for_each      = var.create_private_api ? { for k, v in var.private_api_routes : k => v if v.integration_type == "LAMBDA" } : {}
  statement_id  = "AllowExecutionFromPrivateAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.target_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.private_api[0].execution_arn}/*/${each.value.http_method}${aws_api_gateway_resource.private_resources[each.key].path}"
}

# Create resources, methods, and integrations for ECS backends
resource "aws_api_gateway_resource" "ecs_resources" {
  for_each = var.ecs_microservices
  
  rest_api_id = aws_api_gateway_rest_api.public_api.id
  parent_id   = aws_api_gateway_rest_api.public_api.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "ecs_methods" {
  for_each = var.ecs_microservices

  authorization = "AWS_IAM"
  rest_api_id   = aws_api_gateway_rest_api.public_api.id
  resource_id   = aws_api_gateway_resource.ecs_resources[each.key].id
  http_method   = "ANY"
}

resource "aws_api_gateway_integration" "ecs_integrations" {
  for_each = length(var.ecs_microservices) > 0 ? var.ecs_microservices : {}
  
  rest_api_id             = aws_api_gateway_rest_api.public_api.id
  resource_id             = aws_api_gateway_resource.ecs_resources[each.key].id
  http_method             = aws_api_gateway_method.ecs_methods[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.ecs_load_balancers[each.key].dns_name}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main[0].id
}

# VPC Link for connecting API Gateway to internal ALBs
resource "aws_api_gateway_vpc_link" "main" {
  count       = length(var.ecs_microservices) > 0 ? 1 : 0
  name        = "${var.api_name}-vpc-link"
  target_arns = [for k, v in aws_lb.ecs_load_balancers : v.arn]
}

# ECS Cluster for microservices
resource "aws_ecs_cluster" "main" {
  name = "${coalesce(var.api_name, var.api_name)}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ALBs for ECS microservices
resource "aws_lb" "ecs_load_balancers" {
  for_each = var.ecs_microservices
  
  name               = "${each.value.name}-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = data.aws_subnets.private.ids
  security_groups    = [aws_security_group.alb.id]
}

# Get VPC subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for ALBs
resource "aws_security_group" "alb" {
  name        = "${coalesce(var.api_name, var.api_name)}-alb-sg"
  description = "Security group for ALBs"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Target groups for ALBs
resource "aws_lb_target_group" "ecs" {
  for_each = var.ecs_microservices
  
  name     = "${each.value.name}-tg"
  port     = each.value.container_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  
  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }
}

# ALB listeners
resource "aws_lb_listener" "ecs" {
  for_each = var.ecs_microservices
  
  load_balancer_arn = aws_lb.ecs_load_balancers[each.key].arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs[each.key].arn
  }
}

# ECS Fargate services
resource "aws_ecs_service" "microservices" {
  for_each = var.ecs_microservices
  
  name            = each.value.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.microservices[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }
}

# ECS Task definitions
resource "aws_ecs_task_definition" "microservices" {
  for_each = var.ecs_microservices
  
  family                   = each.value.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  
  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = "${aws_ecr_repository.microservices[each.key].repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = each.value.container_port
          hostPort      = each.value.container_port
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${each.value.name}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECR repositories for microservices
resource "aws_ecr_repository" "microservices" {
  for_each = var.ecs_microservices
  
  name = each.value.name
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM execution role for ECS tasks
resource "aws_iam_role" "ecs_execution_role" {
  name = "${coalesce(var.api_name, var.api_name)}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security group for ECS tasks
resource "aws_security_group" "ecs" {
  name        = "${coalesce(var.api_name, var.api_name)}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


