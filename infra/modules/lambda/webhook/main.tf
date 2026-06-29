# Includes the actual webhook lambda function resource, its data,
# dependencies, and related resources including:
#   - IAM resources (IAM role, assume role & permissions policy documents),
#   - zipped function code data
#   - function url resource (For external HTTP reqs)

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
      "arn:aws:bedrock-agentcore:*:*:agent-runtime/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
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

data "archive_file" "webhook_lambda_code_zip" {
  type = "zip"
  source_dir = var.webhook_lambda_code_folder
  output_path = "${var.zipped_artifact_dump_folder}/webhook_lambda_payload.zip"
}

resource "aws_lambda_function" "webhook_lambda" {
  function_name = var.webhook_lambda_function_name
  role = aws_iam_role.webhook_lambda_role.arn

  filename = data.archive_file.webhook_lambda_code_zip.output_path
  package_type = "Zip"
  runtime = "python3.12"
  handler = "handler.handler"
}

resource "aws_lambda_function_url" "webhook_lambda_url_resource" {
  function_name = aws_lambda_function.webhook_lambda.function_name
  authorization_type = "NONE"
}