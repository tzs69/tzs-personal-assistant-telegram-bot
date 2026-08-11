output "queue_arn" {
  description = "ARN of SQS queue between webhook lambda and invoker lambda"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "URL of SQS queue between webhook lambda and invoker lambda"
  value       = aws_sqs_queue.this.url
}