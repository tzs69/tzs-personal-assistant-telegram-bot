output "role_id" {
  description = "ID of execution lambda role"
  value       = aws_iam_role.base_lambda_role.id
}

output "role_arn" {
  description = "ARN of execution lambda role"
  value       = aws_iam_role.base_lambda_role.arn
}
