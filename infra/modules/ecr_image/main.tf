terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}


resource "aws_ecr_repository" "this" {
  name = var.ecr_repo_name
  force_delete = true
}

locals {
  image_tag = "${var.image_tag_prefix}-${substr(var.source_code_sha, 0, 12)}"
  image_uri = "${aws_ecr_repository.this.repository_url}:${local.image_tag}"
}

resource "docker_image" "this" {
  name = local.image_uri
  build {
    context = var.build_context
    dockerfile = var.dockerfile
    platform = var.platform
    builder = var.builder_name
  }
  triggers = {
    source_code_sha = var.source_code_sha
  }
}

resource "docker_registry_image" "this" {
  name = local.image_uri
  triggers = {
    image_id = docker_image.this.image_id
    source_code_sha = var.source_code_sha
  }
  keep_remotely = false
}