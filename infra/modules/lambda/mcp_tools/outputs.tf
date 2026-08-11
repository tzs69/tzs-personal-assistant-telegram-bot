output "function_arn" {
  description = "ARN of the MCP tools Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the MCP tools Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "execution_role_arn" {
  description = "ARN of the MCP tools Lambda execution role"
  value       = module.mcp_tools_lambda_iam.role_arn
}
