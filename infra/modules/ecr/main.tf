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
  name     = "assets-buildx-builder"
  use      = true
  platform = ["linux/amd64", "linux/arm64"]

  docker_container {
    image = "moby/buildkit:latest"
  }
}

locals {
  src_root            = abspath("${path.module}/../../../src")
  shared_dir          = "${local.src_root}/shared"
  file_ignore_pattern = "(^|/)__pycache__(/|$)|\\.py[cod]$"

  source_dirs = {
    invoker_lambda = "${local.src_root}/lambdas/invoker"
    webhook_lambda = "${local.src_root}/lambdas/webhook"
    router_agent   = "${local.src_root}/agentcore/router_agent"
  }

  filter_source_files = {
    for service_name, source_dir in local.source_dirs : service_name => sort([
      for source_file in fileset(source_dir, "**") : source_file
      if !can(regex(local.file_ignore_pattern, source_file))
    ])
  }

  invoker_lambda_source_files = local.filter_source_files.invoker_lambda
  webhook_lambda_source_files = local.filter_source_files.webhook_lambda
  router_agent_source_files   = local.filter_source_files.router_agent

  shared_files = {
    lambda       = ["schemas.py"]
    router_agent = ["schemas.py", "agentcore_memory.py"]
  }

  filter_shared_files = {
    for service_name, shared_file_names in local.shared_files : service_name => sort([
      for shared_file in fileset(local.shared_dir, "**") : shared_file
      if(
        !can(regex(local.file_ignore_pattern, shared_file))
        && contains(shared_file_names, shared_file)
      )
    ])
  }

  lambda_shared_files       = local.filter_shared_files.lambda
  router_agent_shared_files = local.filter_shared_files.router_agent


  service_images = {
    invoker_lambda = {
      ecr_repo_name    = var.invoker_lambda_ecr_repo_name
      image_tag_prefix = var.invoker_lambda_image_tag_prefix
      build_context    = var.build_context
      builder_name     = docker_buildx_builder.image_builder.name
      platform         = var.lambda_architecture
      dockerfile       = "${local.source_dirs.invoker_lambda}/Dockerfile"
      source_dir       = local.source_dirs.invoker_lambda
      source_files     = local.invoker_lambda_source_files
      shared_files     = local.lambda_shared_files
    }
    webhook_lambda = {
      ecr_repo_name    = var.webhook_lambda_ecr_repo_name
      image_tag_prefix = var.webhook_lambda_image_tag_prefix
      build_context    = var.build_context
      builder_name     = docker_buildx_builder.image_builder.name
      platform         = var.lambda_architecture
      dockerfile       = "${local.source_dirs.webhook_lambda}/Dockerfile"
      source_dir       = local.source_dirs.webhook_lambda
      source_files     = local.webhook_lambda_source_files
      shared_files     = local.lambda_shared_files
    }
    router_agent = {
      ecr_repo_name    = var.router_agent_ecr_repo_name
      image_tag_prefix = var.router_agent_image_tag_prefix
      build_context    = var.build_context
      builder_name     = docker_buildx_builder.image_builder.name
      platform         = var.agentcore_architecture
      dockerfile       = "${local.source_dirs.router_agent}/Dockerfile"
      source_dir       = local.source_dirs.router_agent
      source_files     = local.router_agent_source_files
      shared_files     = local.router_agent_shared_files
    }
  }

  # Trigger service image updates (If the service's owned source code changes)
  code_shas = {
    for service_name, service_vars in local.service_images : service_name => sha256(
      join("", concat(
        [for source_file in service_vars.source_files : filesha256("${service_vars.source_dir}/${source_file}")],
        [for shared_file in service_vars.shared_files : filesha256("${local.shared_dir}/${shared_file}")]
      ))
    )
  }
}

# Modular deployment of each service's container images
module "service_images" {
  source   = "../ecr_image"
  for_each = local.service_images

  ecr_repo_name    = each.value.ecr_repo_name
  image_tag_prefix = each.value.image_tag_prefix
  build_context    = each.value.build_context
  builder_name     = each.value.builder_name
  platform         = each.value.platform
  dockerfile       = each.value.dockerfile
  source_code_sha  = local.code_shas[each.key]
}
