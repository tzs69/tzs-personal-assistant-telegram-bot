terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 6.28.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    use_lockfile=true
  }
}

module "asset_store_ecr_repos" {
  source = "../../modules/ecr"
  agent_runtime_assets_ecr_repo_name = var.agent_runtime_assets_ecr_repo_name
  webhook_lambda_assets_ecr_repo_name = var.webhook_lambda_assets_ecr_repo_name
  agent_runtime_assets_image_tag = var.agent_runtime_assets_image_tag
  webhook_lambda_assets_image_tag = var.webhook_lambda_assets_image_tag
}

module "webhook_lambda_function" {
  source = "../../modules/lambda/webhook"
  webhook_lambda_function_name = var.webhook_lambda_function_name
  webhook_lambda_execution_role_name = var.webhook_lambda_execution_role_name
  agent_runtime_region = var.agent_runtime_region
  tele_pid = var.tele_pid
  tele_bot_api_key = var.tele_bot_api_key
  agent_runtime_arn = module.agentcore_agent_runtime.agent_runtime_arn
  webhook_lambda_image_uri = module.asset_store_ecr_repos.webhook_lambda_assets_image_uri
  webhook_lambda_code_zip_sha = module.asset_store_ecr_repos.webhook_lambda_code_zip_sha
}

module "agentcore_agent_runtime" {
  source = "../../modules/bedrock_agentcore/agent_runtime"
  agent_runtime_name = var.agent_runtime_name
  agent_runtime_execution_role_name = var.agent_runtime_execution_role_name
  agent_runtime_model_id = var.agent_runtime_model_id
  agent_runtime_image_uri = module.asset_store_ecr_repos.agent_runtime_assets_image_uri
  agent_runtime_code_zip_sha = module.asset_store_ecr_repos.agent_runtime_code_zip_sha
  agent_memory_arn = module.agentcore_memory.agent_memory_arn
  agent_memory_id = module.agentcore_memory.agent_memory_id
  agent_memory_region = module.agentcore_memory.agent_memory_region
}

module "agentcore_memory" {
  source = "../../modules/bedrock_agentcore/agent_memory"
  agent_memory_name = var.agent_memory_name
  agent_memory_execution_role_name = var.agent_memory_execution_role_name
}
