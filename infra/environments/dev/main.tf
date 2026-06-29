terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }
  backend "s3" {
    use_lockfile=true
  }
}

module "webhook_lambda_function" {
  source = "../../modules/lambda/webhook"
  webhook_lambda_function_name = var.webhook_lambda_function_name
}

module "agentcore_agent_runtime" {
  source = "../../modules/bedrock_agentcore/agentcore_runtime"
  agent_runtime_name = var.agent_runtime_name
  agent_runtime_artifact_store_s3_bucket_name = var.agent_runtime_artifact_store_s3_bucket_name
  agent_runtime_code_folder = var.agent_runtime_code_folder
  agent_runtime_model_id = var.agent_runtime_model_id
}


# terraform init \
#   -backend-config "profile=tehzeshi" \
#   -backend-config "region=us-east-1" \
#   -backend-config "bucket=tzs-terraform-backend-dev-statefile-bucket" \
#   -backend-config "key=dev/terraform.tfstate" 
