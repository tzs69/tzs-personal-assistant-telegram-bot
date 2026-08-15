output "harness_id" {
  description = "Unique ID of the AgentCore harness."
  value       = aws_bedrockagentcore_harness.this.harness_id
}

output "harness_arn" {
  description = "ARN of the AgentCore harness."
  value       = aws_bedrockagentcore_harness.this.arn
}
