# GitHub Actions Deployment to Azure Container Registry

This document explains the automated deployment workflow for the chat application to Azure Container Registry (ACR).

## Overview

The GitHub Actions workflow automatically:

1. Builds a Docker image from the `src/` directory
2. Creates a `.env` file from GitHub secrets during the build process
3. Pushes the image to Azure Container Registry
4. Tags the image with both the commit SHA and "latest"

## Prerequisites

### 1. Azure Resources

Ensure you have deployed the Azure infrastructure using the Bicep template:

```bash
az deployment group create \
  --resource-group techworkshop-l300-ai-agents \
  --template-file src/infra/DeployAzureResources.bicep \
  --parameters parameters.json
```

### 2. GitHub Secrets

You need to configure the following secrets in your GitHub repository:

#### `AZURE_CREDENTIALS`

Create an Azure service principal and add its credentials:

```bash
# Create a service principal
az ad sp create-for-rbac --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/techworkshop-l300-ai-agents \
  --sdk-auth
```

Copy the output and create a GitHub secret named `AZURE_CREDENTIALS` with this JSON:

```json
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

#### `ENV`

Create a GitHub secret named `ENV` containing your complete `.env` file content. Use the `src/env_sample.txt` as a template and fill in your actual values:

```bash
# Example content for the ENV secret:
OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT="true"
IS_LOCAL_AUTH="false"
AZURE_OPENAI_ENDPOINT="https://your-ai-foundry.openai.azure.com/"
AZURE_OPENAI_KEY="your-key-here"
# ... (include all your environment variables)
```

## Workflow Details

### Trigger Conditions

The workflow runs when:

- Code is pushed to the `main` branch
- Changes are made to files in the `src/` directory
- Manually triggered via GitHub Actions UI

### Build Process

1. **Checkout**: Gets the latest code from the repository
2. **Azure Login**: Authenticates using the service principal
3. **ACR Discovery**: Automatically finds the container registry name from your resource group
4. **Environment Setup**: Creates `.env` file from the `ENV` GitHub secret
5. **Docker Build**: Builds the image in the `src/` directory context
6. **Push to ACR**: Pushes both SHA-tagged and latest-tagged images
7. **Cleanup**: Removes the temporary `.env` file from the runner

### Security Features

- ✅ `.env` file is created only during the build process
- ✅ `.env` file is never committed to the repository
- ✅ Temporary `.env` file is cleaned up after the build
- ✅ Secrets are passed securely through GitHub secrets
- ✅ Azure authentication uses service principal with limited scope

## Docker Image Details

### Image Tags

- `{registry}.azurecr.io/chat-app:{git-sha}` - Specific version tag
- `{registry}.azurecr.io/chat-app:latest` - Latest version tag

### Dockerfile Modifications

The Dockerfile has been updated to:

- Use `COPY .env* ./` to conditionally copy `.env` files if they exist
- Handle the case where no `.env` file is present during local development
- Maintain compatibility with both CI/CD and local development workflows

## Local Development

For local development, create your own `.env` file in the `src/` directory:

```bash
cd src
cp env_sample.txt .env
# Edit .env with your local values
```

**Important**: Never commit your `.env` file to the repository!

## Troubleshooting

### Workflow Fails at "Get ACR name"

- Verify the resource group name in the workflow file matches your actual resource group
- Ensure your service principal has `Reader` access to the resource group

### Workflow Fails at "Login to Azure Container Registry"

- Check that your Azure Container Registry exists and is accessible
- Verify your service principal has `AcrPush` role on the container registry

### Docker Build Fails

- Review the build logs for specific error messages
- Ensure all required files are present in the `src/` directory
- Check that the `ENV` secret contains valid environment variable syntax

### Missing Environment Variables in Container

- Verify the `ENV` GitHub secret contains all required variables
- Check the format matches the `env_sample.txt` template
- Ensure variable names and values are correct

## Manual Deployment

If you need to deploy manually:

```bash
# Login to Azure
az login

# Get ACR name
ACR_NAME=$(az acr list --resource-group techworkshop-l300-ai-agents --query '[0].name' -o tsv)

# Login to ACR
az acr login --name $ACR_NAME

# Create .env file (copy your values)
cd src
cp env_sample.txt .env
# Edit .env with your values

# Build and push
docker build -t $ACR_NAME.azurecr.io/chat-app:manual .
docker push $ACR_NAME.azurecr.io/chat-app:manual

# Clean up
rm .env
```

## Next Steps

After successful deployment to ACR:

1. Update your Azure App Service to use the new image
2. Configure environment variables in App Service if needed
3. Monitor the application logs in Azure
4. Set up automated deployment to App Service if desired
