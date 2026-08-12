terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    use_lockfile = true
  }
}

module "ecr" {
  source                           = "../../modules/ecr"
  router_agent_ecr_repo_name       = var.router_agent_ecr_repo_name
  router_agent_tools_ecr_repo_name = var.router_agent_tools_ecr_repo_name
  invoker_lambda_ecr_repo_name     = var.invoker_lambda_ecr_repo_name
  webhook_lambda_ecr_repo_name     = var.webhook_lambda_ecr_repo_name
}

module "invoker_lambda_function" {
  source                             = "../../modules/lambda/invoker"
  invoker_lambda_function_name       = var.invoker_lambda_function_name
  invoker_lambda_execution_role_name = var.invoker_lambda_execution_role_name
  tele_pid                           = var.tele_pid
  agent_runtime_arn                  = module.router_agent.agent_runtime_arn
  agent_runtime_region               = var.router_agent_region
  invoker_lambda_image_uri           = module.ecr.invoker_lambda_image_uri
  invoker_lambda_code_zip_sha        = module.ecr.invoker_lambda_image_digest
  webhook_invoker_queue_arn          = module.webhook_invoker_sqs.queue_arn
}

module "webhook_lambda_function" {
  source                             = "../../modules/lambda/webhook"
  webhook_lambda_function_name       = var.webhook_lambda_function_name
  webhook_lambda_execution_role_name = var.webhook_lambda_execution_role_name
  tele_pid                           = var.tele_pid
  tele_bot_api_key                   = var.tele_bot_api_key
  webhook_lambda_image_uri           = module.ecr.webhook_lambda_image_uri
  webhook_lambda_code_zip_sha        = module.ecr.webhook_lambda_image_digest
  webhook_invoker_queue_arn          = module.webhook_invoker_sqs.queue_arn
  webhook_invoker_queue_url          = module.webhook_invoker_sqs.queue_url
}

module "webhook_invoker_sqs" {
  source = "../../modules/sqs"
}

module "router_agent_tools_lambda" {
  source = "../../modules/lambda/mcp_tools"

  function_name       = var.router_agent_tools_lambda_function_name
  execution_role_name = var.router_agent_tools_lambda_execution_role_name
  image_uri           = module.ecr.router_agent_tools_image_uri
  source_code_hash    = module.ecr.router_agent_tools_image_digest
  architecture        = "x86_64"
  timeout             = 60

  environment_variables = {
    TELE_BOT_API_KEY = var.tele_bot_api_key
  }
}

module "agentcore_gateway" {
  source = "../../modules/bedrock_agentcore/agentcore_gateway"

  gateway_name                = var.agentcore_gateway_name
  gateway_execution_role_name = var.agentcore_gateway_execution_role_name
  gateway_description         = var.agentcore_gateway_description

  lambda_target_arns = [
    module.router_agent_tools_lambda.function_arn
  ]
}

module "router_agent_tools_gateway_target" {
  source = "../../modules/bedrock_agentcore/agentcore_gateway/lambda_mcp_target"

  target_name        = var.router_agent_tools_gateway_target_name
  target_description = var.router_agent_tools_gateway_target_description
  gateway_id         = module.agentcore_gateway.gateway_id
  lambda_arn         = module.router_agent_tools_lambda.function_arn

  tool_schemas_json = file(
    "${path.module}/../../../src/lambdas/mcp_tools/router_agent_tools/tool_schemas.json"
  )
}

module "router_agent" {
  source                            = "../../modules/bedrock_agentcore/agent_runtime"
  agent_runtime_name                = var.router_agent_name
  agent_runtime_execution_role_name = var.router_agent_execution_role_name
  agent_runtime_model_id            = var.router_agent_model_id
  agent_runtime_image_uri           = module.ecr.router_agent_image_uri
  agent_runtime_code_zip_sha        = module.ecr.router_agent_image_digest
  agent_memory_arn                  = module.agentcore_memory.agent_memory_arn
  agent_memory_id                   = module.agentcore_memory.agent_memory_id
  agent_memory_region               = module.agentcore_memory.agent_memory_region
  agentcore_gateway_arn             = module.agentcore_gateway.gateway_arn
  agentcore_gateway_url             = module.agentcore_gateway.gateway_url
  agentcore_gateway_region          = var.router_agent_region

  depends_on = [
    module.router_agent_tools_gateway_target
  ]
}

moved {
  from = module.agentcore_agent_runtime
  to   = module.router_agent
}

module "agentcore_memory" {
  source                           = "../../modules/bedrock_agentcore/agent_memory"
  agent_memory_name                = var.agent_memory_name
  agent_memory_execution_role_name = var.agent_memory_execution_role_name
}
