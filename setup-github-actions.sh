#!/bin/bash

# GitHub Actions Setup Helper Script
# This script helps you set up the required secrets for the GitHub Actions workflow

echo "🚀 GitHub Actions Azure Deployment Setup"
echo "======================================="
echo

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI is not installed. You'll need to manually create secrets."
    echo "   Install from: https://cli.github.com/"
    echo
    AUTO_CREATE_SECRETS=false
else
    AUTO_CREATE_SECRETS=true
    echo "✅ GitHub CLI detected - can auto-create secrets"
fi

echo

# Get basic information
read -p "Enter your Azure subscription ID: " SUBSCRIPTION_ID
read -p "Enter your resource group name [techworkshop-l300-ai-agents]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-techworkshop-l300-ai-agents}

echo
echo "Creating Azure service principal..."

# Create service principal
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "github-actions-sp-$(date +%s)" \
  --role contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  --sdk-auth \
  2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Failed to create service principal. Please check your Azure login and permissions."
    exit 1
fi

echo "✅ Service principal created successfully"

# Format the credentials
AZURE_CREDENTIALS=$(echo "$SP_OUTPUT" | jq -c .)

echo
echo "📋 AZURE_CREDENTIALS secret value:"
echo "=================================="
echo "$AZURE_CREDENTIALS"
echo

if [ "$AUTO_CREATE_SECRETS" = true ]; then
    echo "Creating GitHub secret AZURE_CREDENTIALS..."
    echo "$AZURE_CREDENTIALS" | gh secret set AZURE_CREDENTIALS
    if [ $? -eq 0 ]; then
        echo "✅ AZURE_CREDENTIALS secret created successfully"
    else
        echo "❌ Failed to create AZURE_CREDENTIALS secret"
    fi
else
    echo "⚠️  Please manually create a GitHub secret named 'AZURE_CREDENTIALS' with the above value"
fi

echo
echo "📋 Next Steps:"
echo "============="
echo "1. Create a GitHub secret named 'ENV' with your environment variables"
echo "   Use the src/env_sample.txt as a template and fill in your values"
echo
echo "2. If you haven't already, push your changes to GitHub:"
echo "   git add ."
echo "   git commit -m 'Add GitHub Actions workflow for ACR deployment'"
echo "   git push origin main"
echo
echo "3. Your workflow will trigger automatically on the next push to main branch"
echo "   affecting files in the src/ directory"
echo
echo "4. Monitor the deployment at:"
echo "   https://github.com/$(gh repo view --json owner,name -q '.owner.login + \"/\" + .name')/actions"
echo

if [ "$AUTO_CREATE_SECRETS" = false ]; then
    echo "💡 To install GitHub CLI for easier secret management:"
    echo "   https://cli.github.com/"
    echo
fi

echo "🎉 Setup complete! Your GitHub Actions workflow is ready to deploy to Azure Container Registry."