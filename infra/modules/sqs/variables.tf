variable "webhook_invoker_queue_name" {
  type        = string
  description = "Name of SQS queue between webhook lambda and invoker lambda"
  default     = "tzs-pa-tele-bot-webhook-invoker-queue.fifo"
}

variable "webhook_invoker_queue_visibility_timeout" {
  type        = number
  description = "Visibility timeout for webhook-invoker queue"
  default     = 1800
}

variable "webhook_invoker_dlq_name" {
  type        = string
  description = "DLQ for webhook-invoker queue"
  default     = "tzs-pa-tele-bot-webhook-invoker-dlq.fifo"
}