output "role_arn" {
  description = "ARN of base agent harness execution role"
  value       = aws_iam_role.agent_harness_execution.arn
}