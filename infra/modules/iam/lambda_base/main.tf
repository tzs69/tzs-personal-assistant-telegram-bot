data "aws_iam_policy_document" "base_lambda_assume_role" {
  statement {
    sid     = "WebhookLambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "base_lambda_role" {
  name               = var.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.base_lambda_assume_role.json
}

data "aws_iam_policy_document" "base_lambda_permissions" {
  statement {
    sid    = "ECRGetImageAccess"
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
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/*"]
  }
}

resource "aws_iam_role_policy" "base_lambda_inline_policy" {
  role   = aws_iam_role.base_lambda_role.id
  policy = data.aws_iam_policy_document.base_lambda_permissions.json
}
