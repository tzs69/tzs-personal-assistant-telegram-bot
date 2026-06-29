# Includes the actual agentcore agent runtime resource, its data,
# dependencies, and related resources including:
#   - IAM resources (IAM role, assume role & permissions policy documents),
#   - zipped agentcore runtime code data
#   - runtime artifact storage s3 bucket & zipped code uploaded as s3 object

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
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [ 
      "arn:aws:s3:::${var.agent_runtime_artifact_store_s3_bucket_name}", 
      "arn:aws:s3:::${var.agent_runtime_artifact_store_s3_bucket_name}/*" 
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
    effect = "Allow"
    actions = [
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

data "archive_file" "agent_runtime_code_zip" {
  type = "zip"
  source_dir = var.agent_runtime_code_folder
  output_path = "${var.zipped_artifact_dump_folder}/agent_runtime_payload.zip"
}

resource "aws_s3_bucket" "agent_runtime_artifact_storage_bucket" {
  bucket = var.agent_runtime_artifact_store_s3_bucket_name
  force_destroy = true
}

resource "aws_s3_object" "agent_runtime_code_zip_s3_key" {
  bucket = var.agent_runtime_artifact_store_s3_bucket_name
  key = var.agent_runtime_code_zip_s3_key
  source = data.archive_file.agent_runtime_code_zip.output_path
  depends_on = [ aws_s3_bucket.agent_runtime_artifact_storage_bucket ]
}

resource "aws_bedrockagentcore_agent_runtime" "agent_runtime" {
  agent_runtime_name = var.agent_runtime_name
  role_arn = aws_iam_role.agent_runtime_role.arn
  
  agent_runtime_artifact {
    code_configuration {
      entry_point = ["agent.py"]
      runtime = "PYTHON_3_12"
      code {
        s3 {
          bucket = var.agent_runtime_artifact_store_s3_bucket_name
          prefix = var.agent_runtime_code_zip_s3_key
        }
      }
    }

  }
  network_configuration {
    network_mode = "PUBLIC"
  }
  environment_variables = {
    AGENT_RUNTIME_MODEL_ID = var.agent_runtime_model_id
  }
}
