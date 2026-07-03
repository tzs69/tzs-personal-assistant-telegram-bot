terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }
}

provider "aws" {
}

resource "aws_s3_bucket" "terraform-state-file-s3-bucket" {
  bucket = var.backend_s3_bucket_name
  force_destroy = true
}
resource "aws_s3_bucket_versioning" "state-file-bucket-versioning" {
  bucket = var.backend_s3_bucket_name
  versioning_configuration {
    status = "Enabled"
  }
}

