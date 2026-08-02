module "invoker_lambda_iam" {
  source              = "../../iam/lambda_base"
  execution_role_name = var.invoker_lambda_execution_role_name
}

data "aws_iam_policy_document" "invoker_lambda_permissions" {
  statement {
    sid    = "SQSQueueReceiveMessageAccess"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
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

resource "aws_iam_role_policy" "invoker_lambda_inline_policy" {
  role   = module.invoker_lambda_iam.role_id
  policy = data.aws_iam_policy_document.invoker_lambda_permissions.json
}

resource "aws_lambda_function" "invoker_lambda" {
  function_name = var.invoker_lambda_function_name
  role          = module.invoker_lambda_iam.role_arn
  image_uri     = var.invoker_lambda_image_uri
  package_type  = "Image"

  source_code_hash = var.invoker_lambda_code_zip_sha

  environment {
    variables = {
      "AGENT_RUNTIME_ARN"    = var.agent_runtime_arn
      "AGENT_RUNTIME_REGION" = var.agent_runtime_region
    }
  }
  timeout = 300
}

resource "aws_lambda_event_source_mapping" "name" {
  event_source_arn = var.webhook_invoker_queue_arn
  function_name    = aws_lambda_function.invoker_lambda.function_name
  batch_size       = 1
  depends_on       = [aws_iam_role_policy.invoker_lambda_inline_policy]

  enabled = false # Temporary; once source code in place remove
}
