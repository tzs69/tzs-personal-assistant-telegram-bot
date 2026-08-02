resource "aws_sqs_queue" "this" {
  name                       = var.webhook_invoker_queue_name
  fifo_queue                 = true
  message_retention_seconds  = 345600
  visibility_timeout_seconds = var.webhook_invoker_queue_visibility_timeout
}

resource "aws_sqs_queue" "this_dlq" {
  name                      = var.webhook_invoker_dlq_name
  fifo_queue                = true
  message_retention_seconds = 1209600 # 14 days (longer for debugging)
}

resource "aws_sqs_queue_redrive_policy" "main_redrive" {
  queue_url = aws_sqs_queue.this.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.this_dlq.arn
    maxReceiveCount     = 5
  })
}