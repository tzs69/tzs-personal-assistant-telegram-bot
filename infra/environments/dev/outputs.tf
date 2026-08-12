output "webhook_lambda_function_url" {
  value = module.webhook_lambda_function.webhook_lambda_endpoint
}

output "agent_runtime_arn" {
  value = module.router_agent.agent_runtime_arn
}

output "agent_runtime_region" {
  value = var.router_agent_region
}

output "agentcore_gateway_id" {
  value = module.agentcore_gateway.gateway_id
}

output "agentcore_gateway_arn" {
  value = module.agentcore_gateway.gateway_arn
}

output "agentcore_gateway_url" {
  value = module.agentcore_gateway.gateway_url
}

output "router_agent_tools_lambda_arn" {
  value = module.router_agent_tools_lambda.function_arn
}

output "router_agent_tools_gateway_target_id" {
  value = module.router_agent_tools_gateway_target.target_id
}
