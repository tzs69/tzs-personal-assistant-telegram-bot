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
  router_agent_ecr_repo_name = var.router_agent_ecr_repo_name
  webhook_lambda_ecr_repo_name = var.webhook_lambda_ecr_repo_name
}

moved {
  from = module.ecr.module.service_images["agent_runtime"]
  to = module.ecr.module.service_images["router_agent"]
}

module "webhook_lambda_function" {
  source = "../../modules/lambda/webhook"
  webhook_lambda_function_name = var.webhook_lambda_function_name
  webhook_lambda_execution_role_name = var.webhook_lambda_execution_role_name
  agent_runtime_region = var.router_agent_region
  tele_pid = var.tele_pid
  tele_bot_api_key = var.tele_bot_api_key
  agent_runtime_arn = module.router_agent.agent_runtime_arn
  webhook_lambda_image_uri = module.ecr.webhook_lambda_image_uri
  webhook_lambda_code_zip_sha = module.ecr.webhook_lambda_image_digest
}

module "router_agent" {
  source = "../../modules/bedrock_agentcore/agent_runtime"
  agent_runtime_name = var.router_agent_name
  agent_runtime_execution_role_name = var.router_agent_execution_role_name
  agent_runtime_model_id = var.router_agent_model_id
  agent_runtime_image_uri = module.ecr.router_agent_image_uri
  agent_runtime_code_zip_sha = module.ecr.router_agent_image_digest
  agent_memory_arn = module.agentcore_memory.agent_memory_arn
  agent_memory_id = module.agentcore_memory.agent_memory_id
  agent_memory_region = module.agentcore_memory.agent_memory_region
}

moved {
  from = module.agentcore_agent_runtime
  to = module.router_agent
}

module "agentcore_memory" {
  source = "../../modules/bedrock_agentcore/agent_memory"
  agent_memory_name = var.agent_memory_name
  agent_memory_execution_role_name = var.agent_memory_execution_role_name
}
