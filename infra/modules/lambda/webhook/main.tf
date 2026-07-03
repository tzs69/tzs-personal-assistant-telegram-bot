# Includes the actual webhook lambda function resource, its data,
# dependencies, and related resource(s) including:
#   - IAM resources (IAM role, assume role & permissions policy documents),
#   - function url (For external HTTP reqs; tele webhook)

data "aws_iam_policy_document" "webhook_lambda_assume_role" {
  statement {
    sid = "WebhookLambdaAssumeRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "webhook_lambda_role" {
  name = var.webhook_lambda_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.webhook_lambda_assume_role.json
}

data "aws_iam_policy_document" "webhook_lambda_permissions" {
  statement {
    sid = "LambdaInvokeFunctionUrl"
    effect = "Allow"
    actions = [ 
      "lambda:InvokeFunction",
      "lambda:InvokeFunctionUrl"
    ]
    resources = [ 
      "arn:aws:lambda:*"
    ]
  }
  statement {
    sid = "BedrockAgentCoreInvokeAgentRuntime"
    effect = "Allow"
    actions = [ 
      "bedrock-agentcore:InvokeAgentRuntime",
    ]
    resources = [ 
      "arn:aws:bedrock-agentcore:*:*:runtime/*"
    ]
  }
  statement {
    sid = "ECRGetImageAccess"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [ 
      "arn:aws:ecr:*:*:repository/*" 
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [ "arn:aws:logs:*:*:log-group:/aws/lambda/*" ]
  }
}

resource "aws_iam_role_policy" "webhook_lambda_inline_policy" {
  role = aws_iam_role.webhook_lambda_role.id
  policy = data.aws_iam_policy_document.webhook_lambda_permissions.json
}


resource "aws_lambda_function" "webhook_lambda" {
  function_name = var.webhook_lambda_function_name
  role = aws_iam_role.webhook_lambda_role.arn
  image_uri = var.webhook_lambda_image_uri
  package_type = "Image"

  source_code_hash = var.webhook_lambda_code_zip_sha

  environment {
    variables = {
      "AGENT_RUNTIME_ARN" = var.agent_runtime_arn
      "TELE_PID" = var.tele_pid
      "AGENT_RUNTIME_REGION" = var.agent_runtime_region
      "TELE_BOT_API_KEY" = var.tele_bot_api_key
    }
  }
  timeout = 20
}

resource "aws_lambda_function_url" "webhook_lambda_url_resource" {
  function_name = aws_lambda_function.webhook_lambda.function_name
  authorization_type = "NONE"
}
