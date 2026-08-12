# Commons
variable "agent_memory_name" {
  type        = string
  description = "Name of the agentcore memory associated with the agent runtime"
  default     = "tzs_pa_tele_bot_dev_agent_memory"
}
variable "agent_memory_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the agentcore agent memory"
  default     = "tzs-pa-tele-bot-dev-agent-memory-execution-role"
}
variable "tele_pid" {
  type        = string
  description = "Telegram user ID. Use @userinfobot on to get."
}
variable "tele_bot_api_key" {
  type        = string
  description = "Telegram bot API key/token"
}


# Router agent (& deps) resource vars
variable "router_agent_name" {
  type        = string
  description = "Name of the router agent runtime"
  default     = "tzs_pa_tele_bot_dev_router_agent"
}
variable "router_agent_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the router agent runtime"
  default     = "tzs-pa-tele-bot-dev-router-agent-execution-role"
}
variable "router_agent_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built router agent container image"
  default     = "tzs-pa-tele-bot-dev-router-agent-assets-repo"
}
variable "router_agent_model_id" {
  type        = string
  description = "Model ID of the strands agent within the router agent runtime"
}


# Shared AgentCore Gateway
variable "agentcore_gateway_name" {
  type        = string
  description = "Name of the shared AgentCore Gateway"
  default     = "tzs-pa-tele-bot-dev-shared-gateway"
}

variable "agentcore_gateway_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the shared AgentCore Gateway"
  default     = "tzs-pa-tele-bot-dev-agentcore-gateway-execution-role"
}

variable "agentcore_gateway_description" {
  type        = string
  description = "Description of the shared AgentCore Gateway"
  default     = "Shared gateway for agent tools and agent-to-agent communication"
}


# Router agent MCP tools Lambda (& deps) resource vars
variable "router_agent_tools_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the router agent MCP tools Lambda image"
  default     = "tzs-pa-tele-bot-dev-router-agent-tools-assets-repo"
}

variable "router_agent_tools_lambda_function_name" {
  type        = string
  description = "Name of the router agent MCP tools Lambda function"
  default     = "tzs-pa-tele-bot-dev-router-agent-tools"
}

variable "router_agent_tools_lambda_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the router agent MCP tools Lambda"
  default     = "tzs-pa-tele-bot-dev-router-agent-tools-lambda-execution-role"
}

variable "router_agent_tools_gateway_target_name" {
  type        = string
  description = "Name of the router agent tools target registered with the shared AgentCore Gateway"
  default     = "router-agent-tools"
}

variable "router_agent_tools_gateway_target_description" {
  type        = string
  description = "Description of the router agent tools Gateway target"
  default     = "MCP tools for the router agent"
}


# Invoker lambda (& deps) resource vars
variable "invoker_lambda_function_name" {
  type        = string
  description = "Name of the invoker lambda function"
  default     = "tzs-pa-tele-bot-dev-invoker-lambda"
}
variable "invoker_lambda_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the invoker lambda function"
  default     = "tzs-pa-tele-bot-dev-invoker-lambda-execution-role"
}
variable "invoker_lambda_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built invoker lambda container image"
  default     = "tzs-pa-tele-bot-dev-invoker-lambda-assets-repo"
}
variable "router_agent_region" {
  type        = string
  description = "The region the router agent runtime resides in. For use in invoker lambda to invoke router agent runtime"
  default     = "us-east-1"
}


# Webhook lambda (& deps) resource vars
variable "webhook_lambda_function_name" {
  type        = string
  description = "Name of the webhook lambda function"
  default     = "tzs-pa-tele-bot-dev-webhook-lambda"
}
variable "webhook_lambda_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the webhook lambda function"
  default     = "tzs-pa-tele-bot-dev-webhook-lambda-execution-role"
}
variable "webhook_lambda_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built webhook lambda container image"
  default     = "tzs-pa-tele-bot-dev-webhook-lambda-assets-repo"
}
