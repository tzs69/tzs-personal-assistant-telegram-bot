variable "webhook_lambda_function_name" {
  type = string
  description = "Name of the webhook lambda function"
  default = "email-summarizer-telegram-bot-webhook-lambda"
}

variable "webhook_lambda_code_folder" {
  type = string
  description = "Relative path of webhook lambda source code folder"
  default = "../../../src/webhook_lambda"
}

variable "zipped_artifact_dump_folder" {
  type = string
  description = "Relative path to deployment/runtime artifacts dumping folder"
  default = "../../../src/_artifacts"
}