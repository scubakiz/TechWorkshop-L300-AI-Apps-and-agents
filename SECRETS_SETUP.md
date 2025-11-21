# GitHub Secrets Setup for AI Agent Workflows

This repository includes scripts to automatically create GitHub repository secrets from your environment variables, eliminating the need to manually configure each secret through the GitHub web interface.

## Quick Start

### Prerequisites

1. **GitHub CLI installed**: Download from [cli.github.com](https://cli.github.com/)
2. **GitHub CLI authenticated**: Run `gh auth login`
3. **Environment file created**: Copy `src/env_sample.txt` to `src/.env` and fill in your values

### Usage

#### Windows (PowerShell)

```powershell
# Basic usage - reads from src/.env
.\create-github-secrets.ps1

# Dry run to see what would be created
.\create-github-secrets.ps1 -DryRun

# Specify custom .env file location
.\create-github-secrets.ps1 -EnvFile "path\to\your\.env"

# Specify different repository
.\create-github-secrets.ps1 -Repository "owner/repository-name"
```

#### Linux/macOS (Bash)

```bash
# Make script executable (Linux/macOS only)
chmod +x create-github-secrets.sh

# Basic usage - reads from src/.env
./create-github-secrets.sh

# Dry run to see what would be created
./create-github-secrets.sh --dry-run

# Specify custom .env file location
./create-github-secrets.sh --env-file "path/to/your/.env"

# Specify different repository
./create-github-secrets.sh --repository "owner/repository-name"
```

## What Secrets Are Created

The script creates all secrets required by the AI Agent workflows:

### Core Azure Authentication

- `AZURE_CREDENTIALS` - Complete JSON credentials for Azure login action
- `AZURE_CLIENT_ID` - Service Principal Client ID
- `AZURE_CLIENT_SECRET` - Service Principal Client Secret
- `AZURE_TENANT_ID` - Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID

### Azure AI Project Settings

- `AZURE_AI_AGENT_ENDPOINT` - Azure AI Agent endpoint URL
- `AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME` - Model deployment name

### Agent IDs (Required)

- `CUSTOMER_LOYALTY_AGENT_ID` - Customer Loyalty Agent ID
- `INTERIOR_DESIGNER_AGENT_ID` - Interior Designer Agent ID
- `INVENTORY_AGENT_ID` - Inventory Agent ID
- `CORA_AGENT_ID` - Cora (Shopper) Agent ID

### Optional Services

- `AZURE_OPENAI_ENDPOINT` - Azure OpenAI endpoint
- `AZURE_OPENAI_KEY` - Azure OpenAI API key
- `GPT_DEPLOYMENT_NAME` - GPT model deployment name
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Application Insights connection
- `STORAGE_ACCOUNT_NAME` - Azure Storage account name
- `STORAGE_CONTAINER_NAME` - Storage container name
- `GPT_IMAGE_1_ENDPOINT` - Image generation endpoint
- `GPT_IMAGE_1_DEPLOYMENT` - Image generation deployment
- `GPT_IMAGE_1_API_VERSION` - Image generation API version
- `GPT_IMAGE_1_SUBSCRIPTION_KEY` - Image generation subscription key

## Environment File Setup

1. Copy the sample environment file:

   ```bash
   cp src/env_sample.txt src/.env
   ```

2. Edit `src/.env` and fill in your Azure resource values:

   ```bash
   # Required for all workflows
   AZURE_AI_AGENT_ENDPOINT="https://your-ai-project.cognitiveservices.azure.com"
   AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME="gpt-4.1"

   # Required agent IDs (get these after creating your agents)
   customer_loyalty="agent-id-1234"
   interior_designer="agent-id-5678"
   inventory_agent="agent-id-9012"
   cora="agent-id-3456"

   # Required for service principal authentication
   AZURE_CLIENT_ID="your-client-id"
   AZURE_CLIENT_SECRET="your-client-secret"
   AZURE_TENANT_ID="your-tenant-id"
   AZURE_SUBSCRIPTION_ID="your-subscription-id"

   # Optional: Azure OpenAI (for Customer Loyalty Agent)
   AZURE_OPENAI_ENDPOINT="https://your-openai.openai.azure.com"
   AZURE_OPENAI_KEY="your-openai-key"
   gpt_deployment="gpt-4"

   # Optional: Storage (for Interior Design Agent)
   storage_account_name="yourstorageaccount"
   storage_container_name="images"

   # Optional: Application Insights
   APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=your-key;..."
   ```

## Azure Service Principal Setup

To create the required Azure Service Principal for authentication:

```bash
# Create service principal
az ad sp create-for-rbac --name "github-actions-ai-agents" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --json-auth

# The output will include the values you need for:
# AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
```

## Script Features

- ✅ **Validation**: Checks for GitHub CLI installation and authentication
- ✅ **Safety**: Dry-run mode to preview changes before applying
- ✅ **Smart Detection**: Auto-detects current repository if not specified
- ✅ **Error Handling**: Clear error messages and rollback on failures
- ✅ **Comprehensive**: Creates all secrets required by all agent workflows
- ✅ **Secure**: Values are masked in output logs
- ✅ **Cross-Platform**: PowerShell script for Windows, Bash script for Linux/macOS

## Troubleshooting

### Common Issues

1. **GitHub CLI not authenticated**

   ```bash
   gh auth login
   ```

2. **Missing .env file**

   ```bash
   cp src/env_sample.txt src/.env
   # Then edit src/.env with your values
   ```

3. **Permission denied (Linux/macOS)**

   ```bash
   chmod +x create-github-secrets.sh
   ```

4. **Repository not found**
   - Ensure you're in the correct directory
   - Or specify the repository explicitly: `--repository owner/repo`

### Verification

After running the script, verify secrets were created:

```bash
gh secret list
```

You can also check in the GitHub web interface:
`Settings` → `Secrets and variables` → `Actions`

## Manual Alternative

If you prefer to set secrets manually, you can use the GitHub CLI directly:

```bash
# Example: Set a single secret
gh secret set AZURE_AI_AGENT_ENDPOINT --body "https://your-endpoint.com"

# Or use the web interface at:
# https://github.com/owner/repo/settings/secrets/actions
```

## Security Notes

- 🔐 The `.env` file contains sensitive information - ensure it's in `.gitignore`
- 🔐 Secrets are encrypted by GitHub and only accessible to workflows
- 🔐 Use service principal authentication (not personal credentials) for production
- 🔐 Regularly rotate your Azure credentials and update secrets accordingly
