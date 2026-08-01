output "webhook_lambda_function_url" {
  value = module.webhook_lambda_function.webhook_lambda_endpoint
}

output "agent_runtime_arn" {
  value = module.router_agent.agent_runtime_arn
}

output "agent_runtime_region" {
  value = var.router_agent_region
}