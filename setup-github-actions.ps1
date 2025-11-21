# GitHub Actions Setup Helper Script for PowerShell
# This script helps you set up the required secrets for the GitHub Actions workflow

Write-Host "🚀 GitHub Actions Azure Deployment Setup" -ForegroundColor Cyan
Write-Host "======================================="
Write-Host

# Check if Azure CLI is installed
try {
    az --version | Out-Null
} catch {
    Write-Host "❌ Azure CLI is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if GitHub CLI is installed
try {
    gh --version | Out-Null
    $AUTO_CREATE_SECRETS = $true
    Write-Host "✅ GitHub CLI detected - can auto-create secrets" -ForegroundColor Green
} catch {
    Write-Host "⚠️  GitHub CLI is not installed. You'll need to manually create secrets." -ForegroundColor Yellow
    Write-Host "   Install from: https://cli.github.com/"
    $AUTO_CREATE_SECRETS = $false
}

Write-Host

# Get basic information
$SUBSCRIPTION_ID = Read-Host "Enter your Azure subscription ID"
$RESOURCE_GROUP = Read-Host "Enter your resource group name [techworkshop-l300-ai-agents]"
if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
    $RESOURCE_GROUP = "techworkshop-l300-ai-agents"
}

Write-Host
Write-Host "Creating Azure service principal..." -ForegroundColor Yellow

# Create service principal
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$spName = "github-actions-sp-$timestamp"

try {
    $SP_OUTPUT = az ad sp create-for-rbac `
        --name $spName `
        --role contributor `
        --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" `
        --sdk-auth `
        2>$null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create service principal"
    }

    Write-Host "✅ Service principal created successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create service principal. Please check your Azure login and permissions." -ForegroundColor Red
    exit 1
}

# Format the credentials
$AZURE_CREDENTIALS = $SP_OUTPUT -join "`n"

Write-Host
Write-Host "📋 AZURE_CREDENTIALS secret value:" -ForegroundColor Cyan
Write-Host "=================================="
Write-Host $AZURE_CREDENTIALS
Write-Host

if ($AUTO_CREATE_SECRETS) {
    Write-Host "Creating GitHub secret AZURE_CREDENTIALS..." -ForegroundColor Yellow
    try {
        $AZURE_CREDENTIALS | gh secret set AZURE_CREDENTIALS
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ AZURE_CREDENTIALS secret created successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to create AZURE_CREDENTIALS secret" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Failed to create AZURE_CREDENTIALS secret: $_" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  Please manually create a GitHub secret named 'AZURE_CREDENTIALS' with the above value" -ForegroundColor Yellow
}

Write-Host
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "============="
Write-Host "1. Create a GitHub secret named 'ENV' with your environment variables"
Write-Host "   Use the src/env_sample.txt as a template and fill in your values"
Write-Host
Write-Host "2. If you haven't already, push your changes to GitHub:"
Write-Host "   git add ."
Write-Host "   git commit -m 'Add GitHub Actions workflow for ACR deployment'"
Write-Host "   git push origin main"
Write-Host
Write-Host "3. Your workflow will trigger automatically on the next push to main branch"
Write-Host "   affecting files in the src/ directory"
Write-Host
Write-Host "4. Monitor the deployment in GitHub Actions tab of your repository"
Write-Host

if (-not $AUTO_CREATE_SECRETS) {
    Write-Host "💡 To install GitHub CLI for easier secret management:" -ForegroundColor Blue
    Write-Host "   https://cli.github.com/"
    Write-Host
}

Write-Host "🎉 Setup complete! Your GitHub Actions workflow is ready to deploy to Azure Container Registry." -ForegroundColor Green