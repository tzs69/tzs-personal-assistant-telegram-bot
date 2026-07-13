# Agentcore agent runtime module

variable "agent_runtime_name" {
  type = string
  description = "Name of the agentcore agent runtime"
  default = "tzs_pa_tele_bot_dev_agent_runtime"
}

variable "agent_runtime_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the agentcore agent runtime"
  default = "tzs-pa-tele-bot-dev-agent-runtime-execution-role"
}

variable "agent_runtime_model_id" {
  type = string
  description = "Model ID of the strands agent within the agent runtime"
}


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

variable "tele_pid" {
  type = string
  description = "Telegram user ID. Use @userinfobot on to get."
}

variable "tele_bot_api_key" {
  type = string
  description = "Telegram bot API key/token"
}

variable "agent_runtime_region" {
  type = string
  description = "The region the agent runtime resides in. Shld be same as aws region"
  default = "us-east-1"
}


variable "agent_runtime_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built agent runtime container image"
  default = "tzs-pa-tele-bot-dev-agent-runtime-assets-repo"
}

variable "webhook_lambda_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built webhook lambda container image"
  default = "tzs-pa-tele-bot-dev-webhook-lambda-assets-repo"
}


variable "agent_memory_name" {
  type = string
  description = "Name of the agentcore memory associated with the agent runtime"
}

variable "agent_memory_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the agentcore agent memory"
}
