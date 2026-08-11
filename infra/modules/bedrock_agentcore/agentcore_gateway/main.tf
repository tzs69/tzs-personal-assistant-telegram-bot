data "aws_iam_policy_document" "agentcore_gateway_assume_role" {
  statement {
    sid     = "BedrockAgentCoreAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agentcore_gateway_role" {
  name               = var.gateway_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.agentcore_gateway_assume_role.json
}

data "aws_iam_policy_document" "agentcore_gateway_permissions" {
  count = length(var.lambda_target_arns) > 0 ? 1 : 0

  statement {
    sid       = "InvokeLambdaTargets"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = var.lambda_target_arns
  }
}

resource "aws_iam_role_policy" "agentcore_gateway_permission_policy" {
  count = length(var.lambda_target_arns) > 0 ? 1 : 0

  role   = aws_iam_role.agentcore_gateway_role.id
  policy = data.aws_iam_policy_document.agentcore_gateway_permissions[0].json
}

resource "aws_bedrockagentcore_gateway" "this" {
  name            = var.gateway_name
  description     = var.gateway_description
  role_arn        = aws_iam_role.agentcore_gateway_role.arn
  authorizer_type = "AWS_IAM"
  tags            = var.tags
}
