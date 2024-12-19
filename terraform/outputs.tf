output "api_gateway_url" {
  value = aws_api_gateway_stage.api_stage.invoke_url
}

output "api_gateway_details" {
  value = {
    url         = aws_api_gateway_stage.api_stage.invoke_url
    rest_api_id = aws_api_gateway_rest_api.lambda_api.id
    stage_name  = aws_api_gateway_stage.api_stage.stage_name
  }
}
