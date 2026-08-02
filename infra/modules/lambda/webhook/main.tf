module "webhook_lambda_iam" {
  source              = "../../iam/lambda_base"
  execution_role_name = var.webhook_lambda_execution_role_name
}

data "aws_iam_policy_document" "webhook_lambda_permissions" {
  statement {
    sid    = "SQSQueueSendMessageAccess"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      var.webhook_invoker_queue_arn
    ]
  }
  statement {
    sid    = "BedrockAgentCoreInvokeAgentRuntime"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
    ]
    resources = [
      "arn:aws:bedrock-agentcore:*:*:runtime/*"
    ]
  }
}

resource "aws_iam_role_policy" "webhook_lambda_inline_policy" {
  role   = module.webhook_lambda_iam.role_id
  policy = data.aws_iam_policy_document.webhook_lambda_permissions.json
}

resource "aws_lambda_function" "webhook_lambda" {
  function_name = var.webhook_lambda_function_name
  role          = module.webhook_lambda_iam.role_arn
  image_uri     = var.webhook_lambda_image_uri
  package_type  = "Image"

  source_code_hash = var.webhook_lambda_code_zip_sha

  environment {
    variables = {
      "AGENT_RUNTIME_ARN"    = var.agent_runtime_arn
      "TELE_PID"             = var.tele_pid
      "AGENT_RUNTIME_REGION" = var.agent_runtime_region
      "TELE_BOT_API_KEY"     = var.tele_bot_api_key
      "SQS_QUEUE_URL"        = var.webhook_invoker_queue_url
    }
  }
  timeout = 20
}

resource "aws_lambda_function_url" "webhook_lambda_url_resource" {
  function_name      = aws_lambda_function.webhook_lambda.function_name
  authorization_type = "NONE"
}

# Temp; not to commit
moved {
  from = aws_iam_role.webhook_lambda_role
  to   = module.webhook_lambda_iam.aws_iam_role.base_lambda_role
}