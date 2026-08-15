variable "harness_name" {
  type        = string
  description = "Name of the AgentCore harness."
}

variable "execution_role_arn" {
  type        = string
  description = "ARN of the IAM role assumed by the AgentCore harness."
}

variable "model_id" {
  type        = string
  description = "Bedrock model ID used by the harness."
}

variable "system_prompt" {
  type        = string
  description = "Default system prompt for the harness."
}

variable "gateway_arn" {
  type        = string
  description = "ARN of shared AgentCore gateway."
}

variable "gateway_name" {
  type        = string
  description = "Name of shared AgentCore gateway."
}

variable "allowed_tools" {
  type        = list(string)
  description = "Explicit allowlist of tools available to the harness."

  validation {
    condition     = length(var.allowed_tools) > 0
    error_message = "allowed_tools must contain at least one tool pattern."
  }
}

variable "model_temperature" {
  type        = number
  description = "Sampling temperature for the harness model."
  default     = 0.2
}

variable "model_top_p" {
  type        = number
  description = "Top-p sampling value for the harness model."
  default     = 0.9
}

variable "max_iterations" {
  type        = number
  description = "Maximum number of model/tool-loop iterations."
  default     = 6

  validation {
    condition     = var.max_iterations >= 1
    error_message = "max_iterations must be at least 1."
  }
}

variable "max_tokens" {
  type        = number
  description = "Maximum number of output tokens per harness invocation."
  default     = 4096
}

variable "timeout_seconds" {
  type        = number
  description = "Harness invocation timeout in seconds."
  default     = 300
}
