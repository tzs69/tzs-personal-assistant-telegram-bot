variable "function_name" {
  type        = string
  description = "Name of the MCP tools Lambda function"
}

variable "execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the MCP tools Lambda"
}

variable "image_uri" {
  type        = string
  description = "Container image URI used by the MCP tools Lambda"
}

variable "source_code_hash" {
  type        = string
  description = "Image digest used to trigger MCP tools Lambda source updates"
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables passed to the MCP tools Lambda"
  default     = {}
  sensitive   = true
}

variable "architecture" {
  type        = string
  description = "Instruction set architecture used by the MCP tools Lambda"
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be either x86_64 or arm64."
  }
}

variable "memory_size" {
  type        = number
  description = "Memory allocated to the MCP tools Lambda in MB"
  default     = 128
}

variable "timeout" {
  type        = number
  description = "Maximum MCP tools Lambda execution time in seconds"
  default     = 20
}
