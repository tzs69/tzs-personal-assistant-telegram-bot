
variable "agent_memory_name" {
  type = string
  description = "Name of the agentcore memory associated with the agent runtime"
}

variable "agent_memory_execution_role_name" {
  type = string
  description = "Name of the IAM execution role used by the agentcore agent memory"
}
