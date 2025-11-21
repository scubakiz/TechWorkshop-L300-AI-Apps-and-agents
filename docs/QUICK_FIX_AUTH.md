# Quick Fix for "Azure CLI not found on path" Error

If you're seeing this error when deploying to Azure:

```
azure.identity._exceptions.CredentialUnavailableError: Azure CLI not found on path
```

## Immediate Solution

**For Azure Deployment:**

1. In your Azure App Service, go to Configuration > Application Settings
2. Add or update: `IS_LOCAL_AUTH = false`
3. Save and restart the application

**Alternative:** Remove the `IS_LOCAL_AUTH` setting entirely (default is false)

## Why This Happens

- The app is trying to use Azure CLI authentication (`AzureCliCredential`)
- Azure CLI is not available in the Azure container environment
- Setting `IS_LOCAL_AUTH=false` forces the use of `DefaultAzureCredential` with managed identity

## Verification

Run the diagnostic script to check your configuration:

```bash
python src/diagnose_auth.py
```

## For Local Development

If you want to use Azure CLI authentication locally:

1. Set `IS_LOCAL_AUTH=true` in your `.env` file
2. Run `az login` to authenticate
3. Verify with `az account show`

For complete documentation, see [AUTHENTICATION.md](AUTHENTICATION.md)
