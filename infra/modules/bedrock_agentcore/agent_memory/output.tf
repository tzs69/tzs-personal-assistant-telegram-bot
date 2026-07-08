output "agent_memory_arn" {
  value = aws_bedrockagentcore_memory.agent_memory.arn
}

output "agent_memory_id" {
  value = aws_bedrockagentcore_memory.agent_memory.id
}

output "agent_memory_region" {
    value = aws_bedrockagentcore_memory.agent_memory.region
}
