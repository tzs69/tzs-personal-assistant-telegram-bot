module "mcp_tools_lambda_iam" {
  source              = "../../iam/lambda_base"
  execution_role_name = var.execution_role_name
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = module.mcp_tools_lambda_iam.role_arn
  image_uri     = var.image_uri
  package_type  = "Image"
  architectures = [var.architecture]

  source_code_hash = var.source_code_hash
  memory_size      = var.memory_size
  timeout          = var.timeout

  environment {
    variables = var.environment_variables
  }
}
