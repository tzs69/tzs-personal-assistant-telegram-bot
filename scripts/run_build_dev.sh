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

# Artifacts cleanup helper to be run from ./infra/environments/dev only
cleanup_artifacts() {
    cd ../../../src/_artifacts

    case $1 in --error)
        if [[ $2 == "true" || $2 -eq 1 ]]; then
            echo -e "\n${RED}${bold}Error encountered, cleaning up runtime artifacts...${normal}${NC}"
            rm -rf *
            cd ..
            rm -d _artifacts
            exit 1
        fi
    esac
    echo -e "\n${GREEN}${bold}Apply/Destroy successful, cleaning up runtime artifacts...${normal}${NC}"
    rm -rf *
    cd ..
    rm -d _artifacts
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

# Directory to store all deployment/runtime artifacts (empty if alr exists)
mkdir -p src/_artifacts
rm -f src/_artifacts/*.zip

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
            cleanup_artifacts --error 1
        }
    else
        cat terraform_init_error.log
        rm terraform_init_error.log
        echo -e "$terraform_init_error_message"
        cleanup_artifacts --error 1
    fi
fi

# Terraform plan
if [[ $destroy == "true" ]]; then
    terraform plan -input=false -destroy -out=tfplan || cleanup_artifacts --error 1
    echo -e "\n${RED}${bold}Applying destroy plan...${Normal}${NC}"
else
    terraform plan -input=false -out=tfplan || cleanup_artifacts --error 1
    echo -e "\n${GREEN}${bold}Applying built plan...${Normal}${NC}"
fi

# Terraform apply/destroy
terraform apply -input=false -compact-warnings -auto-approve tfplan || cleanup_artifacts --error 1
export WEBHOOK_LAMBDA_URL=$(terraform output -raw webhook_lambda_function_url)
rm tfplan

cleanup_artifacts

# Run webhook set/delete script

cd ../scripts # cd points to root/src agter artifact cleanup
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
cd ..
