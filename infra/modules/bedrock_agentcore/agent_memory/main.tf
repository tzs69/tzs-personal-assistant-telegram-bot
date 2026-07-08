data "aws_iam_policy_document" "agent_memory_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent_memory_role" {
  name = var.agent_memory_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.agent_memory_assume_role.json
}

resource "aws_iam_role_policy_attachment" "agent_memory_permission_policy" {
    role = aws_iam_role.agent_memory_role.id
    policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockAgentCoreMemoryBedrockModelInferenceExecutionRolePolicy"
}

resource "aws_bedrockagentcore_memory" "agent_memory" {
  name = var.agent_memory_name
  event_expiry_duration = 7
  memory_execution_role_arn = aws_iam_role.agent_memory_role.arn
}

resource "aws_bedrockagentcore_memory_strategy" "agent_memory_strategy_semantic_built_in" {
  name = "agent_memory_strategy_semantic_built_in"
  memory_id = aws_bedrockagentcore_memory.agent_memory.id
  namespaces = [ "/actor/{actorId}/facts/" ]
  type = "SEMANTIC"
}

resource "aws_bedrockagentcore_memory_strategy" "agent_memory_strategy_user_prefs_built_in" {
  name = "agent_memory_strategy_user_prefs_built_in"
  memory_id = aws_bedrockagentcore_memory.agent_memory.id
  namespaces = [ "/actor/{actorId}/preferences/" ]
  type = "USER_PREFERENCE"
}
