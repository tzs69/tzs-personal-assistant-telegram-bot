# Commons
variable "agent_memory_name" {
  type = string
  description = "Name of the agentcore memory associated with the agent runtime"
}
variable "agent_memory_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the agentcore agent memory"
}
variable "tele_pid" {
  type = string
  description = "Telegram user ID. Use @userinfobot on to get."
}
variable "tele_bot_api_key" {
  type = string
  description = "Telegram bot API key/token"
}


# Router agent (& deps) resource vars
variable "router_agent_name" {
  type = string
  description = "Name of the router agent runtime"
  default = "tzs_pa_tele_bot_dev_router_agent"
}
variable "router_agent_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the router agent runtime"
  default = "tzs-pa-tele-bot-dev-router-agent-execution-role"
}
variable "router_agent_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built router agent container image"
  default = "tzs-pa-tele-bot-dev-router-agent-assets-repo"
}
variable "router_agent_model_id" {
  type = string
  description = "Model ID of the strands agent within the router agent runtime"
}


# Webhook lambda (& deps) resource vars
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
variable "webhook_lambda_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built webhook lambda container image"
  default = "tzs-pa-tele-bot-dev-webhook-lambda-assets-repo"
}
variable "router_agent_region" {
  type = string
  description = "The region the router agent runtime resides in. For use in webhook lambda to invoke router agent runtime"
  default = "us-east-1"
}
