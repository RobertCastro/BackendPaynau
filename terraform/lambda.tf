# Trust policy for Lambda role
data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Trust policy for API Gateway
data "aws_iam_policy_document" "apigateway_trust_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Rol para CloudWatch
resource "aws_iam_role" "cloudwatch" {
  name               = "${var.main_resources_name}-apigateway-cloudwatch-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.apigateway_trust_policy.json
}

# Política de CloudWatch al rol
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Cuenta de API Gateway para usar el rol de CloudWatch
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

# Política IAM para acceso a la VPC
data "aws_iam_policy_document" "lambda_vpc_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
}

# Política al rol de la Lambda
resource "aws_iam_role_policy" "lambda_vpc_access" {
  name   = "${var.main_resources_name}-vpc-access"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_vpc_access_policy.json
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.main_resources_name}-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_policy.json
}

# Add "AWSLambdaBasicExecutionRole" to the role for the Lambda Function
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create ZIP file for the source code at deployment time
data "archive_file" "lambda_source_package" {
  type        = "zip"
  source_dir  = local.root_path
  output_path = local.lambda_package_path
  excludes    = [
    "terraform",
    "terraform.tfstate",
    "terraform.tfstate.backup",
    ".terraform",
    "lambda-layers",
    ".git",
    ".gitignore",
    "README.md",
    "*.zip"
  ]
}

# Lambda Layer Install (Dependencias)
resource "null_resource" "lambda_layer_install_deps" {
  provisioner "local-exec" {
    command     = "make install"
    working_dir = local.root_path
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

# Create ZIP file for Lambda Layer (Dependencias)
data "archive_file" "lambda_layer_package" {
  type        = "zip"
  source_dir  = "${local.lambda_layers_root_path}/fastapi/modules"
  output_path = local.lambda_layer_package_path

  depends_on = [null_resource.lambda_layer_install_deps]
}

# Lambda Layer
resource "aws_lambda_layer_version" "lambda_layer" {
  filename                 = "${local.lambda_layers_root_path}/fastapi/modules/lambda_layer_package.zip"
  layer_name               = "${var.main_resources_name}-layer"
  compatible_runtimes      = ["python3.12"]
  compatible_architectures = ["x86_64"]
  source_code_hash         = data.archive_file.lambda_layer_package.output_base64sha256

  depends_on = [data.archive_file.lambda_layer_package]
}

# Lambda Function
resource "aws_lambda_function" "lambda" {
  function_name    = "${var.main_resources_name}-${var.environment}"
  filename         = local.lambda_package_path
  handler         = "app/main.handler"
  role            = aws_iam_role.lambda_role.arn
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 256
  architectures   = ["x86_64"]
  layers          = [aws_lambda_layer_version.lambda_layer.arn]
  source_code_hash = data.archive_file.lambda_source_package.output_base64sha256

  vpc_config {
    subnet_ids         = ["subnet-021ea598cba9335c6", "subnet-0e2bd5db18632bf60"]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      LOG_LEVEL     = "INFO"
      MYSQL_USER    = var.database_user
      MYSQL_PASSWORD = var.database_pass
      MYSQL_HOST    = aws_db_instance.mysql.endpoint
      MYSQL_DATABASE = aws_db_instance.mysql.db_name
    }
  }

  depends_on = [
    data.archive_file.lambda_source_package,
    data.archive_file.lambda_layer_package,
    aws_db_instance.mysql
  ]
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "lambda_api" {
  name = "${var.main_resources_name}-api-${var.environment}"

  binary_media_types = [
    "multipart/form-data",
    "application/json",
    "application/octet-stream",
    "text/html",
    "*/*"
  ]
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

  depends_on = [aws_api_gateway_resource.proxy]
}

# Integración Lambda para el root path
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_rest_api.lambda_api.root_resource_id
  http_method = aws_api_gateway_method.root_method.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.lambda.invoke_arn

  depends_on = [aws_api_gateway_method.root_method]
}

# Integración Lambda para el proxy
resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_method.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.lambda.invoke_arn

  depends_on = [aws_api_gateway_method.proxy_method]
}

# Integración para OPTIONS
resource "aws_api_gateway_integration" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  type        = "MOCK"
  
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
  }

  depends_on = [aws_api_gateway_method.proxy_options]
}

# Respuesta de integración para OPTIONS
resource "aws_api_gateway_integration_response" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE,PATCH,HEAD'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Max-Age"       = "'3600'"
  }

  depends_on = [aws_api_gateway_method.proxy_options, aws_api_gateway_integration.proxy_options]
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
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE,PATCH,HEAD'"
    "gatewayresponse.header.Access-Control-Expose-Headers" = "'*'"
    "gatewayresponse.header.Access-Control-Max-Age" = "'3600'"
    "gatewayresponse.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# Gateway Response para errores 5XX
resource "aws_api_gateway_gateway_response" "cors_5xx" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE,PATCH,HEAD'"
    "gatewayresponse.header.Access-Control-Expose-Headers" = "'*'"
    "gatewayresponse.header.Access-Control-Max-Age" = "'3600'"
    "gatewayresponse.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

# Lambda permissions
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}

# Outputs
output "api_gateway_url" {
  value = aws_api_gateway_stage.api_stage.invoke_url
}

output "api_gateway_details" {
  value = {
    url = aws_api_gateway_stage.api_stage.invoke_url
    rest_api_id = aws_api_gateway_rest_api.lambda_api.id
    stage_name = aws_api_gateway_stage.api_stage.stage_name
  }
}