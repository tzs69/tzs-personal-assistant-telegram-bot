# Includes the actual agentcore agent runtime resource, its data,
# dependencies, and related resource(s) including:
#   - IAM resources (IAM role, assume role & permissions policy documents),

data "aws_iam_policy_document" "agent_runtime_assume_role" {
  statement {
    sid = "BedrockAgentCoreAssumeRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent_runtime_role" {
  name = var.agent_runtime_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.agent_runtime_assume_role.json
}

data "aws_iam_policy_document" "agent_runtime_permissions" {
  statement {
    sid = "BedrockModelInvocationAccess"
    effect = "Allow"
    actions = [ 
      "bedrock:InvokeModel", 
      "bedrock:InvokeModelWithResponseStream" 
    ]
    resources = [ 
      "arn:aws:bedrock:*::foundation-model/*", 
      "arn:aws:bedrock:*:*:inference-profile/*" 
    ]
  }
  statement {
    sid = "MarketPlaceSubscriptionAccess"
    effect = "Allow"
    actions = [ 
      "aws-marketplace:Subscribe",
      "aws-marketplace:ViewSubscriptions",
      "aws-marketplace:Unsubscribe" 
    ]
    resources = ["*"]
  }
  statement {
    sid = "ECRAuth"
    effect = "Allow"
    actions = [ "ecr:GetAuthorizationToken" ]
    resources = [ "*" ]
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
    resources = [ "arn:aws:logs:*:*:log-group:/aws/bedrock-agentcore/*" ]
  }
}

resource "aws_iam_role_policy" "agent_runtime_permission_policy" {
  role = aws_iam_role.agent_runtime_role.id
  policy = data.aws_iam_policy_document.agent_runtime_permissions.json
}


resource "aws_bedrockagentcore_agent_runtime" "agent_runtime" {
  agent_runtime_name = var.agent_runtime_name
  role_arn = aws_iam_role.agent_runtime_role.arn
  
  agent_runtime_artifact {
    container_configuration {
      container_uri = var.agent_runtime_image_uri
    }
  }
  network_configuration {
    network_mode = "PUBLIC"
  }
  environment_variables = {
    AGENT_RUNTIME_MODEL_ID = var.agent_runtime_model_id
    _CODE_SHA = var.agent_runtime_code_zip_sha
  }

}
