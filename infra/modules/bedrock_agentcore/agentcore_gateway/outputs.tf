output "gateway_id" {
  description = "ID of the shared AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.this.gateway_id
}

output "gateway_arn" {
  description = "ARN of the shared AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.this.gateway_arn
}

output "gateway_url" {
  description = "URL of the shared AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.this.gateway_url
}

output "gateway_execution_role_arn" {
  description = "ARN of the IAM execution role assumed by the shared AgentCore Gateway"
  value       = aws_iam_role.agentcore_gateway_role.arn
}
