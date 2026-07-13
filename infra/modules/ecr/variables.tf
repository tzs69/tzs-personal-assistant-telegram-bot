variable "agent_runtime_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built agent runtime container image"
}

variable "webhook_lambda_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built webhook lambda container image"
}

variable "agent_runtime_image_tag_prefix" {
  type = string
  default = "agent-runtime"
}

variable "webhook_lambda_image_tag_prefix" {
  type = string
  default = "webhook-lambda"
}

variable "build_context" {
  type = string
  description = "Shared base context of image builds"
  default = "../../../src"
}

variable "lambda_architecture" {
  type = string
  description = "platform architecture lambda runs on (preferred)"
  default = "linux/amd64"
}

variable "agentcore_architecture" {
  type = string
  description = "platform architecture agentcore runs on (bo pian)"
  default = "linux/arm64"
}
