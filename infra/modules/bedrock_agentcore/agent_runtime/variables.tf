variable "agent_runtime_name" {
  type = string
  description = "Name of the agentcore agent runtime"
}

variable "agent_runtime_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the agentcore agent runtime"
}

variable "agent_runtime_model_id" {
  type = string
  description = "Model ID of the strands agent within the agent runtime"
}

variable "agent_runtime_image_uri" {
  type = string
}

variable "agent_runtime_code_zip_sha" {
  type = string
}
