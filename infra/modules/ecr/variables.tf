variable "agent_runtime_assets_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built agent runtime container image"
}

variable "webhook_lambda_assets_ecr_repo_name" {
  type = string
  description = "AWS ECR repository to store the built webhook lambda container image"
}

variable "agent_runtime_assets_image_tag" {
  type = string
  default = "agent-runtime-latest"
}

variable "webhook_lambda_assets_image_tag" {
  type = string
  default = "webhook-lambda-latest"
}

variable "webhook_lambda_code_folder" {
  type = string
  description = "Relative path of webhook lambda source code folder"
  default = "../../../src/webhook_lambda"
}

variable "agent_runtime_code_folder" {
  type = string
  description = "Relative path of agent runtime source code folder"
  default = "../../../src/agent_runtime"
}

variable "zipped_artifact_dump_folder" {
  type = string
  description = "Relative path to deployment/runtime artifacts dumping folder"
  default = "../../../src/_artifacts"
}