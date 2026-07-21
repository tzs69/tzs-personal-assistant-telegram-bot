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

# Multi-architecture builder to accomodate for modular container image builds 
# - x86_64 -> Lambda
# - ARM64 -> Agentcore
resource "docker_buildx_builder" "image_builder" {
  name = "assets-buildx-builder"
  use = true
  platform = [ "linux/amd64", "linux/arm64" ]
  
  docker_container {
    image = "moby/buildkit:latest"
  }
}

locals {
  src_root = abspath("${path.module}/../../../src")
  webhook_lambda_source_dir = "${local.src_root}/lambdas/webhook"
  router_agent_source_dir = "${local.src_root}/agentcore/router_agent"
  shared_dir = "${local.src_root}/shared"

  # Source code for each service (exclusively owned + shared)
  # Direct source code files (excl. shared)
  ignore_pattern = "(^|/)__pycache__(/|$)|\\.py[cod]$"
  webhook_lambda_source_files = sort([
    for source_file in fileset(local.webhook_lambda_source_dir, "**") : source_file
    if !can(regex(local.ignore_pattern, source_file))
  ])
  router_agent_source_files = sort([
    for source_file in fileset(local.router_agent_source_dir, "**") : source_file
    if !can(regex(local.ignore_pattern, source_file))
  ])

  # Lambda - Agentcore shared files (schema file as of now)
  lambda_agentcore_shared_file_names = [ "schemas.py" ]
  lambda_agentcore_shared_files = sort([
    for shared_file in fileset(local.shared_dir, "**") : shared_file
    if (
      !can(regex(local.ignore_pattern, shared_file)) 
      && contains(local.lambda_agentcore_shared_file_names, shared_file)
    )
  ])
  agentcore_shared_file_names = [ "agentcore_memory.py" ]
  agentcore_shared_files = sort([
    for shared_file in fileset(local.shared_dir, "**") : shared_file
    if (
      !can(regex(local.ignore_pattern, shared_file))
      && contains(local.agentcore_shared_file_names, shared_file)
    )
  ])

  service_images = {
    webhook_lambda = {
      ecr_repo_name = var.webhook_lambda_ecr_repo_name
      image_tag_prefix = var.webhook_lambda_image_tag_prefix
      build_context = var.build_context
      builder_name = docker_buildx_builder.image_builder.name
      platform = var.lambda_architecture
      dockerfile = "${local.webhook_lambda_source_dir}/Dockerfile"
      source_dir = local.webhook_lambda_source_dir
      source_files = local.webhook_lambda_source_files
      shared_files = local.lambda_agentcore_shared_files
    }
    router_agent = {
      ecr_repo_name = var.router_agent_ecr_repo_name
      image_tag_prefix = var.router_agent_image_tag_prefix
      build_context = var.build_context
      builder_name = docker_buildx_builder.image_builder.name
      platform = var.agentcore_architecture
      dockerfile = "${local.router_agent_source_dir}/Dockerfile"
      source_dir = local.router_agent_source_dir
      source_files = local.router_agent_source_files
      shared_files = concat(local.lambda_agentcore_shared_files, local.agentcore_shared_files)
    }
  }

  # Trigger service image updates (If the service's owned source code changes)
  code_shas = {
    for service_name, service_vars in local.service_images : service_name => sha256(
      join("", concat(
        [ for source_file in service_vars.source_files : filesha256("${service_vars.source_dir}/${source_file}") ],
        [ for shared_file in service_vars.shared_files : filesha256("${local.shared_dir}/${shared_file}") ]
      ))
    )
  }
}

# Modular deployment of each service's container images
module "service_images" {
  source = "../ecr_image"
  for_each = local.service_images

  ecr_repo_name = each.value.ecr_repo_name
  image_tag_prefix = each.value.image_tag_prefix
  build_context = each.value.build_context
  builder_name = each.value.builder_name
  platform = each.value.platform
  dockerfile = each.value.dockerfile
  source_code_sha = local.code_shas[each.key]
}
