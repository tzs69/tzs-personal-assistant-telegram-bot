variable "gateway_name" {
  type        = string
  description = "Name of the shared AgentCore Gateway"
}

variable "gateway_execution_role_name" {
  type        = string
  description = "Name of the IAM execution role used by the shared AgentCore Gateway"
}

variable "gateway_description" {
  type        = string
  description = "Description of the shared AgentCore Gateway"
  default     = null
}

variable "lambda_target_arns" {
  type        = set(string)
  description = "ARNs of all Lambda targets that the shared AgentCore Gateway may invoke"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the shared AgentCore Gateway"
  default     = {}
}
