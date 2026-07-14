output "image_uri" {
  value = docker_registry_image.this.name
  description = "Pushed ECR image URI"
}

output "image_digest" {
  value = docker_registry_image.this.sha256_digest
  description = "Source code hash used to trigger image rebuild"
}