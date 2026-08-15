resource "aws_bedrockagentcore_harness" "this" {
  harness_name       = var.harness_name
  execution_role_arn = var.execution_role_arn

  model {
    bedrock_model_config {
      model_id    = var.model_id
      temperature = var.model_temperature
      top_p       = var.model_top_p
    }
  }

  system_prompt {
    text = var.system_prompt
  }

  tool {
    type = "agentcore_gateway"
    name = var.gateway_name

    config {
      agentcore_gateway {
        gateway_arn = var.gateway_arn
      }
    }
  }

  allowed_tools   = var.allowed_tools
  max_iterations  = var.max_iterations
  max_tokens      = var.max_tokens
  timeout_seconds = var.timeout_seconds
}
