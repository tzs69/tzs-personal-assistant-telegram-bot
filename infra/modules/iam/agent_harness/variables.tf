variable "harness_name" {
  type        = string
  description = "Name of the AgentCore harness."
}

variable "gateway_arn" {
  type        = string
  description = "ARN of the AgentCore Gateway that the harness may invoke."
}
