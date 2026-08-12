output "target_id" {
  description = "ID of the AgentCore Gateway Lambda target"
  value       = aws_bedrockagentcore_gateway_target.this.target_id
}
