output "webhook_lambda_endpoint" {
  value = aws_lambda_function_url.webhook_lambda_url_resource.function_url
  description = "Webhook lambda endpoint to receive HTTP requests from telegram API."
}
