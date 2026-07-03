output "agent_runtime_arn" {
  value = aws_bedrockagentcore_agent_runtime.agent_runtime.agent_runtime_arn
  description = "Agent runtime arn for use by webhook lambda to hit agentcore runtime endpoint."
}