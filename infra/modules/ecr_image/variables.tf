variable "ecr_repo_name" {
  type = string
  description = "Name of ecr repo for the image"
}

variable "image_tag_prefix" {
  type = string
  description = "Prefix for full image tag inside of image ecr repo. Suffix set to soruce code sha"
}

variable "source_code_sha" {
  type = string
  description = "Concatenated hash values of all of the service's source code files (incl. shared)"
}

variable "build_context" {
  type = string
  description = "context of image build"
  default = "../../../src"
}

variable "dockerfile" {
  type = string
  description = "absolute filepath of the service's dockerfile"
}

variable "platform" {
  type = string
  description = "Platform/architecture the service source code runs on. x86_64 for lambda; ARM64 for agentcore runtime"
}

variable "builder_name" {
  type = string
  description = "Name of the image builder as defined in parent ecr module"
  default = "images_buildx_builder"
}
