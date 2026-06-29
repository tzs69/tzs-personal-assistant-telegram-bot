#!/usr/bin/env bash
set -e

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

    case $1 in -error)
        if [[ $2 == "true" || $2 -eq 1 ]]; then
            echo -e "${RED}${bold}Error encountered, cleaning up runtime artifacts...${normal}${NC}"
            rm -rf *
            cd ..
            rm -d _artifacts
            exit 1
        fi
    esac
    echo -e "${GREEN}${bold}Apply/Destroy complete, cleaning up runtime artifacts...${normal}${NC}"
    rm -rf *
    cd ..
    rm -d _artifacts
}

# Destroy or apply-only terraform script
destroy=false
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -destroy)
            if [[ $2 == "true" || $2 -eq 1 ]]; then
                echo -e "${YELLOW}${bold}Running destroy script\n${normal}${NC}"
                destroy=true
            else
                echo -e "${YELLOW}${bold}Unknown value found for argument -destroy: $2, skipping...\n${normal}${NC}"
            fi
            shift 2
        ;;
        *)
            echo -e "${YELLOW}Unknown argument detected: -$1, skipping...\n${NC}"
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

# Directory to store all deployment/runtime artifacts (empty if alr exists)
mkdir -p src/_artifacts
rm -f src/_artifacts/*.zip

# Execute terraform commands
cd infra/environments/dev
echo -e "\n${GREEN}${bold}Initializing Terraform...${Normal}${NC}"

AWS_PROFILE_STR=$AWS_PROFILE
AWS_REGION_STR=$AWS_REGION
BACKEND_S3_BUCKET_NAME_STR=$BACKEND_S3_BUCKET_NAME
terraform init -input=false\
    -backend-config "profile=${AWS_PROFILE_STR}" \
    -backend-config "region=${AWS_REGION_STR}" \
    -backend-config "bucket=${BACKEND_S3_BUCKET_NAME_STR}"\
    -backend-config "key=dev/terraform.tfstate" 

if [[ $destroy == "true" ]]; then
    terraform plan -input=false -destroy -out=tfplan || cleanup_artifacts -error 1
    echo -e "\n${RED}${bold}Applying destroy plan...${Normal}${NC}"
else
    terraform plan -input=false -out=tfplan || cleanup_artifacts -error 1
    echo -e "\n${GREEN}${bold}Applying built plan...${Normal}${NC}"
fi

terraform apply -input=false -compact-warnings -auto-approve tfplan || cleanup_artifacts -error 1
rm tfplan

cleanup_artifacts
