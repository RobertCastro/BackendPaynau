terraform {
  backend "s3" {
    bucket = "lambda-terraform-backend-dev"
    key    = "terraform.fastapi.json"
    region = "us-east-1"
  }
}
