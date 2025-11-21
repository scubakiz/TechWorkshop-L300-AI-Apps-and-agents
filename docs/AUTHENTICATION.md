# Azure Authentication Configuration

This project supports two authentication methods for Azure AI services, controlled by the `IS_LOCAL_AUTH` environment variable.

## Authentication Methods

### Local Development (IS_LOCAL_AUTH="true")

- **Primary**: `AzureCliCredential` - Uses Azure CLI login credentials
- **Fallback**: `DefaultAzureCredential` - If Azure CLI authentication fails
- **Usage**: For local development where developers have logged in via `az login`

### Azure Deployment (IS_LOCAL_AUTH="false" or not set)

- **Primary**: `DefaultAzureCredential` - Uses managed identity or other Azure-native authentication
- **Usage**: For production deployments to Azure where managed identity is available

## Configuration

Add to your `.env` file:

```bash
# Set to "true" for local development with Azure CLI
IS_LOCAL_AUTH="true"

# Set to "false" or omit for Azure deployment with managed identity
IS_LOCAL_AUTH="false"
```

## Affected Files

The following files implement this dual authentication approach:

- `src/chat_app.py` - Main application with AIProjectClient
- `src/app/agents/customerLoyaltyAgent_initializer.py` - Customer loyalty agent
- `src/app/agents/interiorDesignAgent_initializer.py` - Interior design agent
- `src/app/agents/inventoryAgent_initializer.py` - Inventory agent
- `src/app/agents/shopperAgent_initializer.py` - Shopper agent (Cora)

## Authentication Flow

1. Check `IS_LOCAL_AUTH` environment variable
2. If `"true"` (case-insensitive):
   - Try `AzureCliCredential` first
   - Test the credential by attempting to get a token
   - Fall back to `DefaultAzureCredential` if Azure CLI is unavailable or fails
   - Log which method is being used
3. If `"false"` or not set:
   - Use `DefaultAzureCredential` directly
   - Suitable for Azure deployment scenarios with managed identity

## Benefits

- **Flexibility**: Works both locally and in Azure deployment
- **Reliability**: Fallback mechanism prevents authentication failures
- **Clarity**: Clear logging of which authentication method is used
- **Security**: Uses appropriate credential types for each environment

## Troubleshooting

### Local Development Issues

1. Ensure you're logged in: `az login`
2. Verify correct subscription: `az account show`
3. Check environment variable: `IS_LOCAL_AUTH="true"`

### Azure Deployment Issues

1. Ensure managed identity is enabled for the Azure resource
2. Verify environment variable: `IS_LOCAL_AUTH="false"` or not set
3. Check Azure AD permissions for the managed identity

### Common Errors

**"Azure CLI not found on path"**

- This occurs when `IS_LOCAL_AUTH="true"` but the app is running in Azure
- **Solution**: Set `IS_LOCAL_AUTH="false"` or remove it from your Azure App Settings
- The application will automatically fall back to `DefaultAzureCredential`

**Authentication fails in both local and Azure**

- Verify your Azure AD permissions
- For local: Run `az login` and `az account show`
- For Azure: Check that managed identity is enabled and has proper permissions
