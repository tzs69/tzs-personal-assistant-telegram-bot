# This file provisions all the container resources and ECR repositories
# necessary for the containerization and storage of source code artifacts 
# used during the instantiation of external module resource(s): 
#  - Agentcore agent runtime
#  - Webhook lambda function

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  registry_auth {
    address  = data.aws_ecr_authorization_token.token.proxy_endpoint
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

resource "aws_ecr_repository" "agent_runtime_assets_ecr_repo" {
  name = var.agent_runtime_assets_ecr_repo_name
  force_delete = true
}

resource "aws_ecr_repository" "webhook_lambda_assets_ecr_repo" {
  name = var.webhook_lambda_assets_ecr_repo_name
  force_delete = true
}

# Multi-architecture builder to accomodate for modular container image builds 
# - x86_64 -> Lambda
# - ARM64 -> Agentcore
resource "docker_buildx_builder" "asset_image_builder" {
  name = "assets-buildx-builder"
  use = true
  platform = [ "linux/amd64", "linux/arm64" ]
  
  docker_container {
    image = "moby/buildkit:latest"
  }
}

locals {
  agent_runtime_assets_image_uri = "${aws_ecr_repository.agent_runtime_assets_ecr_repo.repository_url}:${var.agent_runtime_assets_image_tag}"
  webhook_lambda_assets_image_uri = "${aws_ecr_repository.webhook_lambda_assets_ecr_repo.repository_url}:${var.webhook_lambda_assets_image_tag}"
}

resource "docker_image" "agent_runtime_assets_image_build" {
  name = local.agent_runtime_assets_image_uri
  build {
    context = "../../../src"
    dockerfile = "${var.agent_runtime_code_folder}/Dockerfile"
    platform = "linux/arm64"
    builder = docker_buildx_builder.asset_image_builder.name
  }
  triggers = {
    "agent_runtime_folder_sha" = data.archive_file.agent_runtime_code_zip.output_sha256
    "schemas_sha" = filesha1("../../../src/schemas.py")
  }
}
resource "docker_image" "webhook_lambda_assets_image_build" {
  name = local.webhook_lambda_assets_image_uri
  build {
    context = "../../../src"
    dockerfile = "${var.webhook_lambda_code_folder}/Dockerfile"
    platform = "linux/amd64"
    builder = docker_buildx_builder.asset_image_builder.name
  }
  triggers = {
    "webhook_lambda_folder_sha" = data.archive_file.webhook_lambda_code_zip.output_sha256
    "schemas_sha" = filesha1("../../../src/schemas.py")
  }
}

resource "docker_registry_image" "agent_runtime_assets_image" {
  name = local.agent_runtime_assets_image_uri
  triggers = {
    image_id = docker_image.agent_runtime_assets_image_build.image_id
  }
  keep_remotely = false
}

resource "docker_registry_image" "webhook_lambda_assets_image" {
  name = local.webhook_lambda_assets_image_uri
  triggers = {
    image_id = docker_image.webhook_lambda_assets_image_build.image_id
  }
  keep_remotely = false
}


# Workaround to trigger infra build updates when source code changes as ecr image tag 
# doesnt change even if source code the container image is built upon changes
resource "terraform_data" "copy_schema" {
  provisioner "local-exec" {
    command = "cp ../../../src/schemas.py ${var.agent_runtime_code_folder}/schemas.py && cp ../../../src/schemas.py ${var.webhook_lambda_code_folder}/schemas.py"
  }
}

data "archive_file" "webhook_lambda_code_zip" {
  type = "zip"
  source_dir = var.webhook_lambda_code_folder
  output_path = "${var.zipped_artifact_dump_folder}/webhook_lambda_payload.zip"
  depends_on = [ terraform_data.copy_schema ]
}
data "archive_file" "agent_runtime_code_zip" {
  type = "zip"
  source_dir = var.agent_runtime_code_folder
  output_path = "${var.zipped_artifact_dump_folder}/agent_runtime_payload.zip"
  depends_on = [ terraform_data.copy_schema ]
}

resource "terraform_data" "remove_schema" {
  provisioner "local-exec" {
    command = "rm -f ${var.webhook_lambda_code_folder}/schemas.py && rm -f ${var.agent_runtime_code_folder}/schemas.py"
  }
  depends_on = [ data.archive_file.webhook_lambda_code_zip, data.archive_file.agent_runtime_code_zip ]
}