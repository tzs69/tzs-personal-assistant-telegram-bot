# Commons
variable "build_context" {
  type        = string
  description = "Shared base context of image builds"
  default     = "../../../src"
}

variable "agentcore_architecture" {
  type        = string
  description = "platform architecture agentcore runs on (bo pian)"
  default     = "linux/arm64"
}

variable "lambda_architecture" {
  type        = string
  description = "platform architecture lambda runs on (preferred)"
  default     = "linux/amd64"
}


# Router agent 
variable "router_agent_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built router agent container image"
}

variable "router_agent_image_tag_prefix" {
  type    = string
  default = "router-agent"
}


# Router agent MCP tools Lambda
variable "router_agent_tools_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built router agent MCP tools Lambda image"
}

variable "router_agent_tools_image_tag_prefix" {
  type    = string
  default = "router-agent-tools"
}


# Invoker lambda
variable "invoker_lambda_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built invoker lambda container image"
}

variable "invoker_lambda_image_tag_prefix" {
  type    = string
  default = "invoker-lambda"
}


# Webhook lambda
variable "webhook_lambda_ecr_repo_name" {
  type        = string
  description = "AWS ECR repository to store the built webhook lambda container image"
}

variable "webhook_lambda_image_tag_prefix" {
  type    = string
  default = "webhook-lambda"
}
