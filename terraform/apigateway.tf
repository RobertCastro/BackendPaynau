# Cuenta de API Gateway para usar el rol de CloudWatch
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "lambda_api" {
  name = "${var.main_resources_name}-api-${var.environment}"

  binary_media_types = ["*/*"]
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Método OPTIONS para el proxy
resource "aws_api_gateway_method" "proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Método ANY para el root path
resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  resource_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# Recurso proxy para las demás rutas
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = "{proxy+}"
}

# Método ANY para el proxy
resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Integración Lambda para el root path
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id            = aws_api_gateway_rest_api.lambda_api.id
  resource_id            = aws_api_gateway_rest_api.lambda_api.root_resource_id
  http_method            = aws_api_gateway_method.root_method.http_method
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.lambda.invoke_arn
  content_handling       = "CONVERT_TO_TEXT"
  passthrough_behavior   = "WHEN_NO_TEMPLATES"
}

# Integración Lambda para el proxy
resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda_api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"

  depends_on = [aws_api_gateway_method.proxy_method]
}

# Integración para OPTIONS
resource "aws_api_gateway_integration" "proxy_options" {
  rest_api_id        = aws_api_gateway_rest_api.lambda_api.id
  resource_id        = aws_api_gateway_resource.proxy.id
  http_method        = aws_api_gateway_method.proxy_options.http_method
  type               = "MOCK"
  content_handling   = "CONVERT_TO_TEXT"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Método respuesta para OPTIONS
resource "aws_api_gateway_method_response" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Max-Age"       = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }

  depends_on = [aws_api_gateway_method.proxy_options]
}

resource "aws_api_gateway_method_response" "proxy_method_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }

  depends_on = [aws_api_gateway_method.proxy_method]
}

# Respuesta de integración para OPTIONS
resource "aws_api_gateway_integration_response" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  status_code = aws_api_gateway_method_response.proxy_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'"
    "method.response.header.Access-Control-Allow-Methods"     = "'GET,POST,PUT,DELETE,OPTIONS,PATCH'"
    "method.response.header.Access-Control-Allow-Origin"      = "'*'"
    "method.response.header.Access-Control-Max-Age"           = "'7200'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  depends_on = [
    aws_api_gateway_method_response.proxy_options,
    aws_api_gateway_integration.proxy_options
  ]
}

resource "aws_api_gateway_integration_response" "proxy_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_method.http_method
  status_code = aws_api_gateway_method_response.proxy_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }

  depends_on = [
    aws_api_gateway_method.proxy_method,
    aws_api_gateway_integration.proxy_integration,
    aws_api_gateway_method_response.proxy_method_response
  ]
}

# Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.root_method.id,
      aws_api_gateway_method.proxy_method.id,
      aws_api_gateway_integration.root_integration.id,
      aws_api_gateway_integration.proxy_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.root_method,
    aws_api_gateway_integration.root_integration,
    aws_api_gateway_method.proxy_method,
    aws_api_gateway_integration.proxy_integration,
  ]
}

# Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  stage_name    = var.environment

  variables = {
    "cors" = "true"
  }

  depends_on = [aws_api_gateway_deployment.api_deployment]
}

# Comportamiento CORS para la API
resource "aws_api_gateway_gateway_response" "cors" {
  rest_api_id    = aws_api_gateway_rest_api.lambda_api.id
  response_type  = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"      = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers"     = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Methods"     = "'GET,POST,PUT,DELETE,OPTIONS,PATCH'"
    "gatewayresponse.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# Gateway Response para errores 5XX
resource "aws_api_gateway_gateway_response" "cors_5xx" {
  rest_api_id    = aws_api_gateway_rest_api.lambda_api.id
  response_type  = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"      = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers"     = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Methods"     = "'OPTIONS,GET,POST,PUT,DELETE,PATCH,HEAD'"
    "gatewayresponse.header.Access-Control-Expose-Headers"    = "'*'"
    "gatewayresponse.header.Access-Control-Max-Age"           = "'3600'"
    "gatewayresponse.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}
