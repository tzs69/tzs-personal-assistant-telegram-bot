variable "target_name" {
  type        = string
  description = "Name of the AgentCore Gateway Lambda target"
}

variable "target_description" {
  type        = string
  description = "Description of the AgentCore Gateway Lambda target"
  default     = null
}

variable "gateway_id" {
  type        = string
  description = "ID of the AgentCore Gateway to register the target with"
}

variable "lambda_arn" {
  type        = string
  description = "ARN of the MCP tool dispatcher Lambda"
}

variable "tool_schemas_json" {
  type        = string
  description = "JSON string containing the MCP tool schema definitions"

  validation {
    condition     = can(jsondecode(var.tool_schemas_json))
    error_message = "tool_schemas_json must contain valid JSON."
  }
}
