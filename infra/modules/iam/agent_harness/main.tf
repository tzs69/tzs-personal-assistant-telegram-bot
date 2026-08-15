data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "agent_harness_permissions" {
  statement {
    sid    = "BedrockModelInvocationAccess"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogPutAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "InvokeAgentCoreGateway"
    effect    = "Allow"
    actions   = ["bedrock-agentcore:InvokeGateway"]
    resources = [var.gateway_arn]
  }
}

resource "aws_iam_role" "agent_harness_execution" {
  name               = "${var.harness_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "agent_harness_permissions" {
  name   = "${var.harness_name}-permissions"
  role   = aws_iam_role.agent_harness_execution.name
  policy = data.aws_iam_policy_document.agent_harness_permissions.json
}

