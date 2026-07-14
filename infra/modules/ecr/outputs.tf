output "agent_runtime_image_uri" {
  value = module.service_images["agent_runtime"].image_uri
  description = "Container image uri reference for agentcore agent runtime provisioning use"
}

output "webhook_lambda_image_uri" {
  value = module.service_images["webhook_lambda"].image_uri
  description = "container image uri reference for webhook lambda provisioning use"
}

output "agent_runtime_image_digest" {
  value = module.service_images["agent_runtime"].image_digest
  description = "image digest of ecr registry image for agent runtime source code"
}

output "webhook_lambda_image_digest" {
  value = module.service_images["webhook_lambda"].image_digest
  description = "image digest of ecr registry image for webhook lambda source code"
}
