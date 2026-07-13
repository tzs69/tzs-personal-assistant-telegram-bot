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

module "ecr" {
  source = "../../modules/ecr"
  agent_runtime_ecr_repo_name = var.agent_runtime_ecr_repo_name
  webhook_lambda_ecr_repo_name = var.webhook_lambda_ecr_repo_name
}

module "webhook_lambda_function" {
  source = "../../modules/lambda/webhook"
  webhook_lambda_function_name = var.webhook_lambda_function_name
  webhook_lambda_execution_role_name = var.webhook_lambda_execution_role_name
  agent_runtime_region = var.agent_runtime_region
  tele_pid = var.tele_pid
  tele_bot_api_key = var.tele_bot_api_key
  agent_runtime_arn = module.agentcore_agent_runtime.agent_runtime_arn
  webhook_lambda_image_uri = module.ecr.webhook_lambda_image_uri
  webhook_lambda_code_zip_sha = module.ecr.webhook_lambda_image_digest
}

module "agentcore_agent_runtime" {
  source = "../../modules/bedrock_agentcore/agent_runtime"
  agent_runtime_name = var.agent_runtime_name
  agent_runtime_execution_role_name = var.agent_runtime_execution_role_name
  agent_runtime_model_id = var.agent_runtime_model_id
  agent_runtime_image_uri = module.ecr.agent_runtime_image_uri
  agent_runtime_code_zip_sha = module.ecr.agent_runtime_image_digest
  agent_memory_arn = module.agentcore_memory.agent_memory_arn
  agent_memory_id = module.agentcore_memory.agent_memory_id
  agent_memory_region = module.agentcore_memory.agent_memory_region
}

module "agentcore_memory" {
  source = "../../modules/bedrock_agentcore/agent_memory"
  agent_memory_name = var.agent_memory_name
  agent_memory_execution_role_name = var.agent_memory_execution_role_name
}
