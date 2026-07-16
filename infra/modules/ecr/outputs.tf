output "router_agent_image_uri" {
  value = module.service_images["router_agent"].image_uri
  description = "Container image uri reference for router agent provisioning use"
}

output "webhook_lambda_image_uri" {
  value = module.service_images["webhook_lambda"].image_uri
  description = "container image uri reference for webhook lambda provisioning use"
}

output "router_agent_image_digest" {
  value = module.service_images["router_agent"].image_digest
  description = "image digest of ecr registry image for router agent source code"
}

output "webhook_lambda_image_digest" {
  value = module.service_images["webhook_lambda"].image_digest
  description = "image digest of ecr registry image for webhook lambda source code"
}
