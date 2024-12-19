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

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "execute-api:Invoke",
      "execute-api:ManageConnections"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${var.main_resources_name}-api-permissions"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
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
