variable "webhook_lambda_function_name" {
  type = string
  description = "Name of the webhook lambda function"
  default = "tzs-pa-tele-bot-dev-webhook-lambda"
}

variable "webhook_lambda_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the webhook lambda function"
  default = "tzs-pa-tele-bot-dev-webhook-lambda-execution-role"
}

variable "agent_runtime_region" {
  type = string
  default = "us-east-1"
}


# Injected during terraform workflow stuff
variable "tele_pid" {
  type = string
  description = "Telegram user ID. Use @userinfobot on to get."
}

variable "tele_bot_api_key" {
  type = string
  description = "Telegram bot API key/token"
}
variable "agent_runtime_arn" {
  type = string
  description = "Derived from agent runtime module during terraform deployment workflow"
}

variable "webhook_lambda_image_uri" {
  type = string
  description = "Derived from ecr module outputs during terraform deployment workflow"
}

variable "webhook_lambda_code_zip_sha" {
  type = string
  description = "Derived from ecr module outputs during terraform deployment workflow"
}
