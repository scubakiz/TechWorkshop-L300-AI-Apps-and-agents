#!/bin/bash
set -euo pipefail

# GitHub Secrets Creation Script for AI Agent Workflows
# This script reads values from a .env file and creates corresponding GitHub repository secrets

# Default values
ENV_FILE="src/.env"
REPOSITORY=""
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Creates GitHub repository secrets from environment variables for AI Agent workflows.

OPTIONS:
    -f, --env-file FILE     Path to .env file (default: src/.env)
    -r, --repository REPO   GitHub repository in format owner/repo (auto-detected if not specified)
    -d, --dry-run          Show what would be created without actually creating secrets
    -h, --help             Show this help message

EXAMPLES:
    $0
    $0 --env-file src/.env --dry-run
    $0 --repository scubakiz/TechWorkshop-L300-AI-Apps-and-agents

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -r|--repository)
            REPOSITORY="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from https://cli.github.com/"
    exit 1
fi

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: Environment file '$ENV_FILE' not found.${NC}"
    echo "You can copy and rename 'src/env_sample.txt' to 'src/.env' and fill in your values."
    exit 1
fi

# Verify GitHub CLI authentication
if ! gh auth status &>/dev/null; then
    echo -e "${RED}Error: GitHub CLI is not authenticated.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Get current repository if not specified
if [[ -z "$REPOSITORY" ]]; then
    if ! REPOSITORY=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        echo -e "${RED}Error: Could not determine current repository.${NC}"
        echo "Please specify --repository parameter."
        exit 1
    fi
    echo -e "${GREEN}Using current repository: $REPOSITORY${NC}"
fi

# Function to read .env file
read_env_file() {
    local file="$1"
    declare -A env_vars
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Parse KEY=VALUE or KEY="VALUE"
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove surrounding quotes
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            env_vars["$key"]="$value"
        fi
    done < "$file"
    
    # Export the associative array (bash 4.3+ feature)
    for key in "${!env_vars[@]}"; do
        printf "%s=%s\n" "$key" "${env_vars[$key]}"
    done
}

# Define secret mappings
declare -A secret_mappings=(
    # Azure Authentication
    ["AZURE_CLIENT_ID"]="AZURE_CLIENT_ID|true|Azure Service Principal Client ID"
    ["AZURE_CLIENT_SECRET"]="AZURE_CLIENT_SECRET|true|Azure Service Principal Client Secret"
    ["AZURE_TENANT_ID"]="AZURE_TENANT_ID|true|Azure Tenant ID"
    ["AZURE_SUBSCRIPTION_ID"]="AZURE_SUBSCRIPTION_ID|true|Azure Subscription ID"
    
    # Azure AI Project
    ["AZURE_AI_AGENT_ENDPOINT"]="AZURE_AI_AGENT_ENDPOINT|true|Azure AI Agent Endpoint"
    ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"]="AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME|true|Azure AI Agent Model Deployment Name"
    
    # Azure OpenAI
    ["AZURE_OPENAI_ENDPOINT"]="AZURE_OPENAI_ENDPOINT|false|Azure OpenAI Endpoint"
    ["AZURE_OPENAI_KEY"]="AZURE_OPENAI_KEY|false|Azure OpenAI API Key"
    ["gpt_deployment"]="GPT_DEPLOYMENT_NAME|false|GPT Deployment Name"
    
    # Application Insights
    ["APPLICATIONINSIGHTS_CONNECTION_STRING"]="APPLICATIONINSIGHTS_CONNECTION_STRING|false|Application Insights Connection String"
    
    # Agent IDs
    ["customer_loyalty"]="CUSTOMER_LOYALTY_AGENT_ID|true|Customer Loyalty Agent ID"
    ["interior_designer"]="INTERIOR_DESIGNER_AGENT_ID|true|Interior Designer Agent ID"
    ["inventory_agent"]="INVENTORY_AGENT_ID|true|Inventory Agent ID"
    ["cora"]="CORA_AGENT_ID|true|Cora (Shopper) Agent ID"
    
    # Azure Storage
    ["storage_account_name"]="STORAGE_ACCOUNT_NAME|false|Azure Storage Account Name"
    ["storage_container_name"]="STORAGE_CONTAINER_NAME|false|Azure Storage Container Name"
    
    # GPT Image Generation
    ["gpt_endpoint"]="GPT_IMAGE_1_ENDPOINT|false|GPT Image Generation Endpoint"
    ["gpt_deployment"]="GPT_IMAGE_1_DEPLOYMENT|false|GPT Image Generation Deployment"
    ["gpt_api_version"]="GPT_IMAGE_1_API_VERSION|false|GPT Image Generation API Version"
    ["gpt_api_key"]="GPT_IMAGE_1_SUBSCRIPTION_KEY|false|GPT Image Generation Subscription Key"
)

# Function to create AZURE_CREDENTIALS JSON
create_azure_credentials_json() {
    local client_id="$1"
    local client_secret="$2"
    local subscription_id="$3"
    local tenant_id="$4"
    
    if [[ -n "$client_id" && -n "$client_secret" && -n "$subscription_id" && -n "$tenant_id" ]]; then
        cat << EOF
{"clientId":"$client_id","clientSecret":"$client_secret","subscriptionId":"$subscription_id","tenantId":"$tenant_id"}
EOF
    fi
}

main() {
    echo -e "${CYAN}Reading environment variables from: $ENV_FILE${NC}"
    
    # Read environment variables
    declare -A env_vars
    while IFS='=' read -r key value; do
        env_vars["$key"]="$value"
    done < <(read_env_file "$ENV_FILE")
    
    echo -e "${GREEN}Found ${#env_vars[@]} environment variables${NC}"
    
    # Track secrets to be created
    declare -a secrets_to_create=()
    declare -a missing_required=()
    
    # Process each secret mapping
    for env_var in "${!secret_mappings[@]}"; do
        IFS='|' read -r secret_name required description <<< "${secret_mappings[$env_var]}"
        
        local env_value="${env_vars[$env_var]:-}"
        
        if [[ -z "$env_value" ]]; then
            if [[ "$required" == "true" ]]; then
                missing_required+=("$env_var")
            fi
            echo -e "${YELLOW}Warning: Environment variable '$env_var' is empty or missing${NC}"
            continue
        fi
        
        secrets_to_create+=("$secret_name|$env_value|$description|$env_var")
    done
    
    # Create AZURE_CREDENTIALS secret
    local azure_credentials
    azure_credentials=$(create_azure_credentials_json \
        "${env_vars[AZURE_CLIENT_ID]:-}" \
        "${env_vars[AZURE_CLIENT_SECRET]:-}" \
        "${env_vars[AZURE_SUBSCRIPTION_ID]:-}" \
        "${env_vars[AZURE_TENANT_ID]:-}")
    
    if [[ -n "$azure_credentials" ]]; then
        secrets_to_create+=("AZURE_CREDENTIALS|$azure_credentials|Azure Service Principal Credentials (JSON)|Computed from Azure auth variables")
    else
        echo -e "${YELLOW}Warning: Could not create AZURE_CREDENTIALS - missing required Azure authentication variables${NC}"
        missing_required+=("AZURE_CREDENTIALS (computed)")
    fi
    
    # Check for missing required secrets
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        echo -e "\n${RED}Missing required environment variables:${NC}"
        printf "${RED}  - %s${NC}\n" "${missing_required[@]}"
        echo -e "\n${YELLOW}Please add these to your .env file before proceeding.${NC}"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            echo -n -e "\nDo you want to continue creating the available secrets? (y/N): "
            read -r continue_choice
            if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
                exit 1
            fi
        fi
    fi
    
    # Display what will be created
    echo -e "\n${CYAN}📋 Secrets to be created (${#secrets_to_create[@]}):${NC}"
    for secret_info in "${secrets_to_create[@]}"; do
        IFS='|' read -r name value description env_var <<< "$secret_info"
        local value_preview
        if [[ ${#value} -gt 20 ]]; then
            value_preview="${value:0:20}..."
        else
            value_preview="$value"
        fi
        
        echo -e "  ${GREEN}✓ $name${NC}"
        echo -e "    ${GRAY}Description: $description${NC}"
        echo -e "    ${GRAY}Source: $env_var${NC}"
        echo -e "    ${GRAY}Value: $value_preview${NC}"
        echo ""
    done
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🔍 DRY RUN MODE: No secrets were actually created.${NC}"
        echo -e "${YELLOW}Remove --dry-run parameter to create the secrets.${NC}"
        exit 0
    fi
    
    # Confirm before proceeding
    echo -e "${CYAN}Repository: $REPOSITORY${NC}"
    echo -n -e "\nDo you want to create these ${#secrets_to_create[@]} secrets? (Y/n): "
    read -r confirm_choice
    if [[ "$confirm_choice" == "n" || "$confirm_choice" == "N" ]]; then
        echo -e "${YELLOW}Cancelled by user.${NC}"
        exit 0
    fi
    
    # Create the secrets
    echo -e "\n${CYAN}🚀 Creating GitHub secrets...${NC}"
    local success_count=0
    local error_count=0
    
    for secret_info in "${secrets_to_create[@]}"; do
        IFS='|' read -r name value description env_var <<< "$secret_info"
        
        echo -n "Creating secret: $name..."
        
        if gh secret set "$name" --body "$value" --repo "$REPOSITORY" &>/dev/null; then
            echo -e " ${GREEN}✅${NC}"
            ((success_count++))
        else
            echo -e " ${RED}❌${NC}"
            ((error_count++))
        fi
    done
    
    # Summary
    echo -e "\n${CYAN}📊 Summary:${NC}"
    echo -e "  ${GREEN}✅ Successfully created: $success_count secrets${NC}"
    if [[ $error_count -gt 0 ]]; then
        echo -e "  ${RED}❌ Failed to create: $error_count secrets${NC}"
    fi
    echo -e "  ${GRAY}📁 Repository: $REPOSITORY${NC}"
    
    if [[ $success_count -gt 0 ]]; then
        echo -e "\n${GREEN}🎉 GitHub secrets have been created successfully!${NC}"
        echo -e "${GREEN}Your AI Agent workflows are now ready to run.${NC}"
    fi
}

# Run main function
main "$@"