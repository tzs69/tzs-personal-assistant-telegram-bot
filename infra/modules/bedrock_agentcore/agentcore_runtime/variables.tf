variable "agent_runtime_name" {
  type = string
  description = "Name of the agentcore agent runtime"
}

variable "agent_runtime_artifact_store_s3_bucket_name" {
  type = string
  description = "Name of the s3 bucket storing agentcore agent runtime code artifacts"
}

variable "agent_runtime_code_folder" {
  type = string
  description = "Relative path of agentcore runtime source code folder"
  default = "../../../src/summarizer_agent"
}

variable "agent_runtime_code_zip_s3_key" {
  type = string
  description = "Key of the zipped agent runtime artifact in artifact store s3 bucket"
  default = "email-summarizer-agent-runtime-code.zip"
}

variable "zipped_artifact_dump_folder" {
  type = string
  description = "Relative path to deployment/runtime artifacts dumping folder"
  default = "../../../src/_artifacts"
}

variable "agent_runtime_model_id" {
  type = string
  description = "Model ID of the strands agent within the agent runtime"
}