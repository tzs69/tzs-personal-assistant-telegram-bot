locals {
  tool_schemas = jsondecode(var.tool_schemas_json)
}

resource "aws_bedrockagentcore_gateway_target" "this" {
  name               = var.target_name
  description        = var.target_description
  gateway_identifier = var.gateway_id

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = var.lambda_arn

        tool_schema {
          dynamic "inline_payload" {
            for_each = local.tool_schemas

            content {
              name        = inline_payload.value.name
              description = inline_payload.value.description

              input_schema {
                type        = inline_payload.value.input_schema.type
                description = lookup(inline_payload.value.input_schema, "description", null)

                dynamic "property" {
                  for_each = lookup(inline_payload.value.input_schema, "properties", [])

                  content {
                    name        = property.value.name
                    type        = property.value.type
                    description = lookup(property.value, "description", null)
                    required    = lookup(property.value, "required", false)
                  }
                }
              }

              dynamic "output_schema" {
                for_each = try(inline_payload.value.output_schema, null) == null ? [] : [inline_payload.value.output_schema]

                content {
                  type        = output_schema.value.type
                  description = lookup(output_schema.value, "description", null)

                  dynamic "property" {
                    for_each = lookup(output_schema.value, "properties", [])

                    content {
                      name        = property.value.name
                      type        = property.value.type
                      description = lookup(property.value, "description", null)
                      required    = lookup(property.value, "required", false)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
