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
  handler          = "app/main.handler"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  architectures    = ["x86_64"]
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  source_code_hash = data.archive_file.lambda_source_package.output_base64sha256

  vpc_config {
    subnet_ids         = ["subnet-021ea598cba9335c6", "subnet-0e2bd5db18632bf60"]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      LOG_LEVEL       = "INFO"
      MYSQL_USER      = var.database_user
      MYSQL_PASSWORD  = var.database_pass
      MYSQL_HOST      = aws_db_instance.mysql.endpoint
      MYSQL_DATABASE  = aws_db_instance.mysql.db_name
    }
  }

  depends_on = [
    data.archive_file.lambda_source_package,
    data.archive_file.lambda_layer_package,
    aws_db_instance.mysql
  ]
}
