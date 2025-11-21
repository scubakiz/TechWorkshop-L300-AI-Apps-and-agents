#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates GitHub repository secrets from environment variables for AI Agent workflows

.DESCRIPTION
    This script reads values from a .env file and creates corresponding GitHub repository secrets
    using the GitHub CLI (gh). It handles all the secrets required by the AI Agent workflows.

.PARAMETER EnvFile
    Path to the .env file (defaults to src/.env)

.PARAMETER Repository
    GitHub repository in format owner/repo (defaults to current repository)

.PARAMETER DryRun
    If specified, shows what secrets would be created without actually creating them

.PARAMETER SkipExisting
    If specified, skips secrets that already exist in the repository (default: true)

.EXAMPLE
    .\create-github-secrets.ps1
    
.EXAMPLE
    .\create-github-secrets.ps1 -EnvFile "src\.env" -DryRun

.EXAMPLE
    .\create-github-secrets.ps1 -Repository "scubakiz/TechWorkshop-L300-AI-Apps-and-agents"
#>

param(
    [string]$EnvFile = "src\.env",
    [string]$Repository = "",
    [switch]$DryRun,
    [bool]$SkipExisting = $true
)

# Check if GitHub CLI is installed
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
    exit 1
}

# Check if .env file exists
if (!(Test-Path $EnvFile)) {
    Write-Error "Environment file '$EnvFile' not found. Please create it from env_sample.txt"
    Write-Host "You can copy and rename 'src/env_sample.txt' to 'src/.env' and fill in your values."
    exit 1
}

# Verify GitHub CLI authentication
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GitHub CLI is not authenticated. Please run: gh auth login"
        exit 1
    }
}
catch {
    Write-Error "Failed to check GitHub CLI authentication status."
    exit 1
}

# Get current repository if not specified
if ([string]::IsNullOrEmpty($Repository)) {
    try {
        $Repository = (gh repo view --json nameWithOwner -q .nameWithOwner)
        Write-Host "Using current repository: $Repository" -ForegroundColor Green
    }
    catch {
        Write-Error "Could not determine current repository. Please specify -Repository parameter."
        exit 1
    }
}

# Define the mapping between environment variables and GitHub secrets
# Format: @{EnvVar = "SECRET_NAME"; Required = $true/$false; Description = "..."}
$SecretMappings = @(
    # Azure Authentication
    @{EnvVar = "AZURE_CLIENT_ID"; Secret = "AZURE_CLIENT_ID"; Required = $true; Description = "Azure Service Principal Client ID" },
    @{EnvVar = "AZURE_CLIENT_SECRET"; Secret = "AZURE_CLIENT_SECRET"; Required = $true; Description = "Azure Service Principal Client Secret" },
    @{EnvVar = "AZURE_TENANT_ID"; Secret = "AZURE_TENANT_ID"; Required = $true; Description = "Azure Tenant ID" },
    @{EnvVar = "AZURE_SUBSCRIPTION_ID"; Secret = "AZURE_SUBSCRIPTION_ID"; Required = $true; Description = "Azure Subscription ID" },
    
    # Azure AI Project
    @{EnvVar = "AZURE_AI_AGENT_ENDPOINT"; Secret = "AZURE_AI_AGENT_ENDPOINT"; Required = $true; Description = "Azure AI Agent Endpoint" },
    @{EnvVar = "AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"; Secret = "AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"; Required = $true; Description = "Azure AI Agent Model Deployment Name" },
    
    # Azure OpenAI
    @{EnvVar = "AZURE_OPENAI_ENDPOINT"; Secret = "AZURE_OPENAI_ENDPOINT"; Required = $false; Description = "Azure OpenAI Endpoint" },
    @{EnvVar = "AZURE_OPENAI_KEY"; Secret = "AZURE_OPENAI_KEY"; Required = $false; Description = "Azure OpenAI API Key" },
    @{EnvVar = "gpt_deployment"; Secret = "GPT_DEPLOYMENT_NAME"; Required = $false; Description = "GPT Deployment Name" },
    
    # Application Insights
    @{EnvVar = "APPLICATIONINSIGHTS_CONNECTION_STRING"; Secret = "APPLICATIONINSIGHTS_CONNECTION_STRING"; Required = $false; Description = "Application Insights Connection String" },
    
    # Agent IDs
    @{EnvVar = "customer_loyalty"; Secret = "CUSTOMER_LOYALTY_AGENT_ID"; Required = $true; Description = "Customer Loyalty Agent ID" },
    @{EnvVar = "interior_designer"; Secret = "INTERIOR_DESIGNER_AGENT_ID"; Required = $true; Description = "Interior Designer Agent ID" },
    @{EnvVar = "inventory_agent"; Secret = "INVENTORY_AGENT_ID"; Required = $true; Description = "Inventory Agent ID" },
    @{EnvVar = "cora"; Secret = "CORA_AGENT_ID"; Required = $true; Description = "Cora (Shopper) Agent ID" },
    
    # Azure Storage (for Interior Design Agent)
    @{EnvVar = "storage_account_name"; Secret = "STORAGE_ACCOUNT_NAME"; Required = $false; Description = "Azure Storage Account Name" },
    @{EnvVar = "storage_container_name"; Secret = "STORAGE_CONTAINER_NAME"; Required = $false; Description = "Azure Storage Container Name" },
    
    # GPT Image Generation (for Interior Design Agent)
    @{EnvVar = "gpt_endpoint"; Secret = "GPT_IMAGE_1_ENDPOINT"; Required = $false; Description = "GPT Image Generation Endpoint" },
    @{EnvVar = "gpt_deployment"; Secret = "GPT_IMAGE_1_DEPLOYMENT"; Required = $false; Description = "GPT Image Generation Deployment" },
    @{EnvVar = "gpt_api_version"; Secret = "GPT_IMAGE_1_API_VERSION"; Required = $false; Description = "GPT Image Generation API Version" },
    @{EnvVar = "gpt_api_key"; Secret = "GPT_IMAGE_1_SUBSCRIPTION_KEY"; Required = $false; Description = "GPT Image Generation Subscription Key" }
)

# Function to read .env file and return hashtable
function Read-EnvFile {
    param([string]$FilePath)
    
    $envVars = @{}
    $content = Get-Content $FilePath -ErrorAction Stop
    
    foreach ($line in $content) {
        $line = $line.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrEmpty($line) -or $line.StartsWith("#")) {
            continue
        }
        
        # Parse KEY=VALUE or KEY="VALUE"
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove quotes if present
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            
            $envVars[$key] = $value
        }
    }
    
    return $envVars
}

# Function to get existing repository secrets
function Get-ExistingSecrets {
    param([string]$Repository)
    
    try {
        $existingSecrets = @()
        $secretsList = gh secret list --repo $Repository --json name 2>$null | ConvertFrom-Json
        if ($secretsList) {
            $existingSecrets = $secretsList | ForEach-Object { $_.name }
        }
        return $existingSecrets
    }
    catch {
        Write-Warning "Could not retrieve existing secrets: $($_.Exception.Message)"
        return @()
    }
}

# Function to create AZURE_CREDENTIALS JSON
function New-AzureCredentialsJson {
    param($EnvVars)
    
    $clientId = $EnvVars["AZURE_CLIENT_ID"]
    $clientSecret = $EnvVars["AZURE_CLIENT_SECRET"]
    $subscriptionId = $EnvVars["AZURE_SUBSCRIPTION_ID"]
    $tenantId = $EnvVars["AZURE_TENANT_ID"]
    
    if ($clientId -and $clientSecret -and $subscriptionId -and $tenantId) {
        $azureCredentials = @{
            clientId       = $clientId
            clientSecret   = $clientSecret
            subscriptionId = $subscriptionId
            tenantId       = $tenantId
        } | ConvertTo-Json -Compress
        
        return $azureCredentials
    }
    
    return $null
}

try {
    Write-Host "Reading environment variables from: $EnvFile" -ForegroundColor Cyan
    $envVars = Read-EnvFile -FilePath $EnvFile
    
    Write-Host "Found $($envVars.Count) environment variables" -ForegroundColor Green
    
    # Get existing secrets if SkipExisting is enabled
    $existingSecrets = @()
    if ($SkipExisting) {
        Write-Host "Checking existing repository secrets..." -ForegroundColor Cyan
        $existingSecrets = Get-ExistingSecrets -Repository $Repository
        if ($existingSecrets.Count -gt 0) {
            Write-Host "Found $($existingSecrets.Count) existing secrets" -ForegroundColor Yellow
        }
    }
    
    # Track secrets to be created
    $secretsToCreate = @()
    $missingRequired = @()
    $skippedSecrets = @()
    
    # Process each secret mapping
    foreach ($mapping in $SecretMappings) {
        $envValue = $envVars[$mapping.EnvVar]
        
        if ([string]::IsNullOrWhiteSpace($envValue)) {
            if ($mapping.Required) {
                $missingRequired += $mapping.EnvVar
            }
            Write-Warning "Environment variable '$($mapping.EnvVar)' is empty or missing"
            continue
        }
        
        # Check if secret already exists and should be skipped
        if ($SkipExisting -and $existingSecrets -contains $mapping.Secret) {
            $skippedSecrets += @{
                Name        = $mapping.Secret
                Description = $mapping.Description
                EnvVar      = $mapping.EnvVar
            }
            continue
        }
        
        $secretsToCreate += @{
            Name        = $mapping.Secret
            Value       = $envValue
            Description = $mapping.Description
            EnvVar      = $mapping.EnvVar
        }
    }
    
    # Skip AZURE_CREDENTIALS creation (assumes it already exists)
    Write-Host "Skipping AZURE_CREDENTIALS creation (assuming it already exists)" -ForegroundColor Yellow
    
    # Check for missing required secrets
    if ($missingRequired.Count -gt 0) {
        Write-Host "`nMissing required environment variables:" -ForegroundColor Red
        $missingRequired | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        Write-Host "`nPlease add these to your .env file before proceeding." -ForegroundColor Yellow
        
        if (!$DryRun) {
            $continue = Read-Host "`nDo you want to continue creating the available secrets? (y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                exit 1
            }
        }
    }
    
    # Display skipped secrets
    if ($skippedSecrets.Count -gt 0) {
        Write-Host "`n⏭️  Secrets already exist (skipping $($skippedSecrets.Count)):" -ForegroundColor Yellow
        $skippedSecrets | ForEach-Object {
            Write-Host "  ⏭️  $($_.Name)" -ForegroundColor Yellow
            Write-Host "    Description: $($_.Description)" -ForegroundColor Gray
            Write-Host "    Source: $($_.EnvVar)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    # Display what will be created
    Write-Host "`n📋 Secrets to be created ($($secretsToCreate.Count)):" -ForegroundColor Cyan
    $secretsToCreate | ForEach-Object {
        $valuePreview = if ($_.Value.Length -gt 20) { "$($_.Value.Substring(0, 20))..." } else { $_.Value }
        Write-Host "  ✓ $($_.Name)" -ForegroundColor Green
        Write-Host "    Description: $($_.Description)" -ForegroundColor Gray
        Write-Host "    Source: $($_.EnvVar)" -ForegroundColor Gray
        Write-Host "    Value: $valuePreview" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    if ($DryRun) {
        Write-Host "🔍 DRY RUN MODE: No secrets were actually created." -ForegroundColor Yellow
        Write-Host "Remove -DryRun parameter to create the secrets." -ForegroundColor Yellow
        exit 0
    }
    
    # Confirm before proceeding
    Write-Host "Repository: $Repository" -ForegroundColor Cyan
    $confirm = Read-Host "`nDo you want to create these $($secretsToCreate.Count) secrets? (Y/n)"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Host "Cancelled by user." -ForegroundColor Yellow
        exit 0
    }
    
    # Create the secrets
    Write-Host "`n🚀 Creating GitHub secrets..." -ForegroundColor Cyan
    $successCount = 0
    $errorCount = 0
    
    foreach ($secret in $secretsToCreate) {
        try {
            Write-Host "Creating secret: $($secret.Name)..." -NoNewline
            
            # Create the secret using gh CLI
            $result = gh secret set $secret.Name --body $secret.Value --repo $Repository 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host " ✅" -ForegroundColor Green
                $successCount++
            }
            else {
                Write-Host " ❌" -ForegroundColor Red
                Write-Host "  Error: $result" -ForegroundColor Red
                $errorCount++
            }
        }
        catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }
    
    # Summary
    Write-Host "`n📊 Summary:" -ForegroundColor Cyan
    Write-Host "  ✅ Successfully created: $successCount secrets" -ForegroundColor Green
    if ($skippedSecrets.Count -gt 0) {
        Write-Host "  ⏭️  Skipped existing: $($skippedSecrets.Count) secrets" -ForegroundColor Yellow
    }
    if ($errorCount -gt 0) {
        Write-Host "  ❌ Failed to create: $errorCount secrets" -ForegroundColor Red
    }
    Write-Host "  📁 Repository: $Repository" -ForegroundColor Gray
    
    if ($successCount -gt 0) {
        Write-Host "`n🎉 GitHub secrets have been created successfully!" -ForegroundColor Green
        Write-Host "Your AI Agent workflows are now ready to run." -ForegroundColor Green
    }
    
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}