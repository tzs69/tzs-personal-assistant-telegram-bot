output "router_agent_image_uri" {
  value       = module.service_images["router_agent"].image_uri
  description = "Container image uri reference for router agent provisioning use"
}

output "router_agent_image_digest" {
  value       = module.service_images["router_agent"].image_digest
  description = "image digest of ecr registry image for router agent source code"
}


output "router_agent_tools_image_uri" {
  value       = module.service_images["router_agent_tools"].image_uri
  description = "Container image URI reference for router agent MCP tools Lambda provisioning"
}

output "router_agent_tools_image_digest" {
  value       = module.service_images["router_agent_tools"].image_digest
  description = "Image digest of ECR registry image for router agent MCP tools Lambda source code"
}


output "invoker_lambda_image_uri" {
  value       = module.service_images["invoker_lambda"].image_uri
  description = "container image uri reference for invoker lambda provisioning use"
}

output "invoker_lambda_image_digest" {
  value       = module.service_images["invoker_lambda"].image_digest
  description = "image digest of ecr registry image for invoker lambda source code"
}


output "webhook_lambda_image_uri" {
  value       = module.service_images["webhook_lambda"].image_uri
  description = "container image uri reference for webhook lambda provisioning use"
}

output "webhook_lambda_image_digest" {
  value       = module.service_images["webhook_lambda"].image_digest
  description = "image digest of ecr registry image for webhook lambda source code"
}
