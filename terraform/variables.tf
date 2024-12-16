variable "environment" {
  type        = string
  description = "Environment for the deployment"
  default     = "dev"
}

variable "main_resources_name" {
  type        = string
  description = "Main resources across the deployment"
  default     = "fastapi-lambda"
}

variable "database_user" {
  description = "Username for the database"
  type        = string
  sensitive   = true
}

variable "database_pass" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "lambda_db"
}