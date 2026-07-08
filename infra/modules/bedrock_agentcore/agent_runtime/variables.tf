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

variable "agent_memory_arn" {
  type = string
  description = "associated agent memory arn"
}

variable "agent_memory_id" {
  type = string
  description = "associated agent memory id"
}

variable "agent_memory_region" {
  type = string
  description = "associated agent memory region"
}
