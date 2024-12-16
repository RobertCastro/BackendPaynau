locals {
  # Project root paths
  root_path = abspath("${path.module}/..")
  app_path  = abspath("${path.module}/../app")
  
  # Lambda paths
  lambda_layers_root_path = abspath("${path.module}/../lambda-layers")
  lambda_package_path     = "${local.root_path}/lambda_package.zip"
  lambda_layer_package_path = "${local.lambda_layers_root_path}/fastapi/modules/lambda_layer_package.zip"
}