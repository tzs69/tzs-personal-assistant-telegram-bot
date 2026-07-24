#!/usr/bin/env bash
set +e

# Text formatting for terminal output
bold=$(tput bold)
normal=$(tput sgr0)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (Resets terminal to default)
PROJECT_ROOT=$(pwd)

# Export environment variables helper
export_variable() {
    local variable_name="$1"
    local variable_value="${!variable_name}"
    local tf_var="$2"

    if [[ -z "$variable_value" ]]; then
        echo -e "${RED}${bold}${variable_name} not set, exiting.${normal}${NC}"
        exit 1
    else
        if [[ "$tf_var" == "true" || "$tf_var" -eq 1 ]]; then
            declare -l variable_name_lower
            variable_name_lower=$variable_name
            export "TF_VAR_$variable_name_lower=$variable_value"
            echo "${variable_name_lower}=$variable_value"
        else
            export "$variable_name=$variable_value"
            echo "${variable_name}=$variable_value"
        fi
    fi
}

setup_test_venv() {
    if [[ ! -d ".venv" ]]; then
        echo -e "\n${BLUE}Creating Python virtual environment for tests...${NC}"
        python -m venv .venv || exit 1
    fi

    if [[ -x "$PROJECT_ROOT/.venv/Scripts/python.exe" ]]; then
        TEST_PYTHON="$PROJECT_ROOT/.venv/Scripts/python.exe"
    elif [[ -x "$PROJECT_ROOT/.venv/Scripts/python" ]]; then
        TEST_PYTHON="$PROJECT_ROOT/.venv/Scripts/python"
    else
        TEST_PYTHON="$PROJECT_ROOT/.venv/bin/python"
    fi

    echo -e "\n${BLUE}Installing Python test dependencies...${NC}"
    "$TEST_PYTHON" -m pip install -e ".[dev]" || exit 1
}

# Destroy or apply-only terraform script
destroy=false
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --destroy)
            if [[ $2 == "true" || $2 -eq 1 ]]; then
                echo -e "${YELLOW}${bold}Running destroy script\n${normal}${NC}"
                destroy=true
            else
                echo -e "${YELLOW}${bold}Unknown value found for argument -destroy: $2, skipping...\n${normal}${NC}"
            fi
            shift 2
        ;;
        *)
            echo -e "${YELLOW}Unknown argument detected: $1, skipping...\n${NC}"
            break
        ;;
    esac
done

# Check if dev folder exists
if [[ ! -d "infra/environments/dev" ]]; then
    echo -e "${RED}${bold}No dev folder found, exiting.${Normal}${NC}"
    exit 1
else
    echo -e "${BLUE}Dev folder found in ./infra/environments/, proceeding...${NC}\n"
fi

# Check terraform installed in system
if ! command -v &>/dev/null "terraform"; then
    echo -e "${RED}${bold}Terraform not installed in system, exiting.${Normal}${NC}"
else
    echo -e "${BLUE}Verified terraform installation in system, proceeding...${NC}\n"
fi

# Check if .env file exists in project root level
if [[ ! -f .env ]]; then
    echo -e "${RED}${bold}.env file not found, exiting.${Normal}${NC}"
    exit 1
else
    set -a
    source .env
    set +a
    echo -e "${BLUE}.env file found and var values loaded, proceeding...${NC}\n"
fi


echo "Config values: "
export_variable AWS_PROFILE
export_variable AWS_REGION
export_variable TELE_PID 1
export_variable TELE_BOT_API_KEY 1
if [[ -z "$AGENT_RUNTIME_MODEL_ID" ]]; then
    echo -e "${RED}${bold}AGENT_RUNTIME_MODEL_ID not set, exiting.${normal}${NC}"
    exit 1
else
    export TF_VAR_router_agent_model_id="$AGENT_RUNTIME_MODEL_ID"
    echo "router_agent_model_id=$AGENT_RUNTIME_MODEL_ID"
fi

if [[ $destroy != "true" ]]; then
    setup_test_venv
fi

# Navigate to infra(dev environment) directory and execute terraform commands
cd infra/environments/dev
echo -e "\n${GREEN}${bold}Initializing Terraform...${Normal}${NC}"

AWS_PROFILE_STR=$AWS_PROFILE
AWS_REGION_STR=$AWS_REGION
BACKEND_S3_BUCKET_NAME_STR=$BACKEND_S3_BUCKET_NAME
if ! terraform init -input=false \
    -backend-config "profile=${AWS_PROFILE_STR}" \
    -backend-config "region=${AWS_REGION_STR}" \
    -backend-config "bucket=${BACKEND_S3_BUCKET_NAME_STR}"\
    -backend-config "key=dev/terraform.tfstate" \
    2> terraform_init_error.log; then # Save error output into .log file

    # Handle backend config change error during init with -reconfigure
    terraform_init_error_message="\n${RED}${bold}Terraform backend initialization failed, exiting.${Normal}${NC}"
    if grep -q "Backend configuration changed" terraform_init_error.log; then
        echo -e "\n${YELLOW}${bold}Terraform backend configuration changes detected, reconfiguring...${normal}${NC}"
        terraform init -reconfigure -input=false \
        -backend-config "profile=${AWS_PROFILE_STR}" \
        -backend-config "region=${AWS_REGION_STR}" \
        -backend-config "bucket=${BACKEND_S3_BUCKET_NAME_STR}"\
        -backend-config "key=dev/terraform.tfstate" 2> terraform_init_error.log && # Overwrite error logs if error again
        { 
            echo -e "\n${YELLOW}${bold}Terraform backend reconfigured and initialized successfully${normal}${NC}";
            rm terraform_init_error.log
        } || 
        {
            cat terraform_init_error.log
            rm terraform_init_error.log
            echo -e "$terraform_init_error_message"
            cd "$PROJECT_ROOT" || exit 1
            exit 1
        }
    else
        cat terraform_init_error.log
        rm terraform_init_error.log
        echo -e "$terraform_init_error_message"
        cd "$PROJECT_ROOT" || exit 1
        exit 1
    fi
fi

# Terraform plan
if [[ $destroy == "true" ]]; then
    terraform plan -input=false -destroy -out=tfplan || exit 1
    echo -e "\n${RED}${bold}Applying destroy plan...${Normal}${NC}"
else
    terraform plan -input=false -out=tfplan || exit 1
    echo -e "\n${GREEN}${bold}Applying built plan...${Normal}${NC}"
fi

# Terraform apply/destroy
terraform apply -input=false -compact-warnings -auto-approve tfplan || exit 1
rm tfplan

if [[ $destroy != "true" ]]; then
    export WEBHOOK_LAMBDA_URL=$(terraform output -raw webhook_lambda_function_url)
    export AGENT_RUNTIME_ARN=$(terraform output -raw agent_runtime_arn)
    export AGENT_RUNTIME_REGION=$(terraform output -raw agent_runtime_region)
fi

# Run webhook set/delete script

cd $PROJECT_ROOT/scripts
if [[ $destroy != "true" ]]; then
    echo -e "\n${GREEN}${bold}Setting Telegram webhook...${Normal}${NC}"
    set_webhook_failed_message="\n${RED}${bold}Set Telegram webhook failed${Normal}${NC}"
    set_webhook_message=$(command python configure_telegram_webhook.py) ||
    { 
        echo -e $set_webhook_failed_message
        exit 1
    }
    if [[ $set_webhook_message == "Webhook set successfully" ]]; then
        echo -e "\n${GREEN}${bold}Telegram webhook set successfully${Normal}${NC}"

        # Run full test suite if webhook successfully set
        echo -e "\n${GREEN}${bold}Running full pytest suite...${normal}${NC}"
        export RUN_LIVE_INTEGRATION_TESTS=1
        cd "$PROJECT_ROOT"
        "$TEST_PYTHON" -m pytest -v || exit 1
    else
        echo -e $set_webhook_failed_message
    fi
else
    echo -e "\n${GREEN}${bold}Deleting Telegram webhook...${Normal}${NC}"
    delete_webhook_failed_message="\n${RED}${bold}Delete Telegram webhook failed${Normal}${NC}"
    delete_webhook_message=$(command python configure_telegram_webhook.py --delete true) ||
    { 
        echo -e $set_webhook_failed_message
        exit 1
    }

    if [[ $delete_webhook_message == "Webhook deleted successfully" ]]; then
        echo -e "\n${GREEN}${bold}Telegram webhook deleted successfully${Normal}${NC}"
    else
        echo -e $set_webhook_failed_message
    fi
fi
cd $PROJECT_ROOT
