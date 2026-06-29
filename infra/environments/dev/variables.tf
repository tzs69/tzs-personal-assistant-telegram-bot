variable "agent_runtime_name" {
  type = string
  description = "Name of the agentcore agent runtime"
}

variable "agent_runtime_artifact_store_s3_bucket_name" {
  type = string
  description = "Name of the s3 bucket storing agentcore agent runtime code artifacts"
}

variable "agent_runtime_code_folder" {
  type = string
  description = "Relative path of agentcore runtime source code folder"
  default = "../../../src/summarizer_agent"
}

variable "agent_runtime_model_id" {
  type = string
  description = "Model ID of the strands agent within the agent runtime"
}


variable "webhook_lambda_function_name" {
  type = string
  description = "Name of the webhook lambda function"
  default = "email-summarizer-telegram-bot-webhook-lambda"
}
