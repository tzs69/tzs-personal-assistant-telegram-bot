# mail-summarizer-agentcore-mcp-exploration
I plan to build a telegram bot that helps me read and provide me a detailed summary of my unread emails in my inbox everyday, using a Strands agent in Bedrock AgentCore with MCP for the LLM side of things and Terraform for infrastructure provisioning.

<br/>

## feature/v1
### Added basic infra provisioning with terraform.
- Backend s3 bucket for state file
- Environments:
  - Bootstrap environment for backend s3 bucket setup 
  - Dev environment with modules
- Modules
  - Agentcore agent runtime
  - Webhook Lambda function

### Added placeholder code for modules (for infra provisioning)
- Agent runtime code under `src/summarizer_agent/`
- Webhook Lambda function code under `src/webhook_lambda/`

### Created shell scripts for running terraform commands
- Remote terraform backend initialization/destruction script (`scripts/run_bootstrap.sh`)
- Terraform dev environment resource provisioning/destruction script (`scripts/run_build_dev.sh`)
