output "agent_runtime_assets_image_uri" {
  value = docker_registry_image.agent_runtime_assets_image.name
  description = "Container image uri reference for agentcore agent runtime provisioning use"
}

output "webhook_lambda_assets_image_uri" {
  value = docker_registry_image.webhook_lambda_assets_image.name
  description = "container image uri reference for webhook lambda provisioning use"
}

output "agent_runtime_code_zip_sha" {
  value = data.archive_file.agent_runtime_code_zip.output_sha256
  description = "file sha256 for temporary agent runtime code zip artifact"
}

output "webhook_lambda_code_zip_sha" {
  value = data.archive_file.webhook_lambda_code_zip.output_sha256
  description = "file sha256 for temporary webhook lambda code zip artifact"
}
