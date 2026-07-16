# Commons
variable "build_context" {
  type = string
  description = "Shared base context of image builds"
  default = "../../../src"
}

variable "agentcore_architecture" {
  type = string
  description = "platform architecture agentcore runs on (bo pian)"
  default = "linux/arm64"
}

variable "lambda_architecture" {
  type = string
  description = "platform architecture lambda runs on (preferred)"
  default = "linux/amd64"
}


# Router agent 
variable "router_agent_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built router agent container image"
}

variable "router_agent_image_tag_prefix" {
  type = string
  default = "router-agent"
}


# Webhook lambda
variable "webhook_lambda_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built webhook lambda container image"
}

variable "webhook_lambda_image_tag_prefix" {
  type = string
  default = "webhook-lambda"
}
