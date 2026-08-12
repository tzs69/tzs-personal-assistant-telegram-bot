variable "invoker_lambda_execution_role_name" {
  type    = string
  default = "tzs-pa-tele-bot-dev-invoker-lambda-execution-role"
}

variable "webhook_invoker_queue_arn" {
  type        = string
  description = "ARN of SQS queue between webhook lambda and invoker lambda"
}

variable "agent_runtime_arn" {
  type        = string
  description = "Derived from agent runtime module during terraform deployment workflow"
}

variable "agent_runtime_region" {
  type    = string
  default = "us-east-1"
}

variable "invoker_lambda_code_zip_sha" {
  type        = string
  description = "Derived from ecr module outputs during terraform deployment workflow"
}

variable "invoker_lambda_image_uri" {
  type        = string
  description = "Derived from ecr module outputs during terraform deployment workflow"
}

variable "invoker_lambda_function_name" {
  type        = string
  description = "Name of the invoker lambda function"
  default     = "tzs-pa-tele-bot-dev-invoker-lambda"
}

variable "tele_pid" {
  type        = string
  description = "Telegram user ID. Use @userinfobot on to get."
}
