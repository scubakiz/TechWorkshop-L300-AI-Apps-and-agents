# Deployment Validation Script
# This script validates that your setup is ready for GitHub Actions deployment

Write-Host "🔍 GitHub Actions Deployment Validation" -ForegroundColor Cyan
Write-Host "======================================="
Write-Host

$issues = @()
$warnings = @()

# Check 1: Dockerfile exists and is properly configured
Write-Host "Checking Dockerfile..." -ForegroundColor Yellow
if (Test-Path "src/Dockerfile") {
    $dockerContent = Get-Content "src/Dockerfile" -Raw
    if ($dockerContent -match "COPY \.env\* \.\/") {
        Write-Host "✅ Dockerfile found and properly configured for .env handling" -ForegroundColor Green
    } else {
        $issues += "Dockerfile doesn't have proper .env handling. Expected 'COPY .env* ./'"
    }
} else {
    $issues += "Dockerfile not found in src/ directory"
}

# Check 2: .gitignore excludes .env files
Write-Host "Checking .gitignore..." -ForegroundColor Yellow
if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    if ($gitignoreContent -match "\.env") {
        Write-Host "✅ .gitignore properly excludes .env files" -ForegroundColor Green
    } else {
        $warnings += ".gitignore should exclude .env files for security"
    }
} else {
    $warnings += ".gitignore file not found"
}

# Check 3: GitHub workflow exists
Write-Host "Checking GitHub Actions workflow..." -ForegroundColor Yellow
if (Test-Path ".github/workflows/deploy-to-acr.yml") {
    Write-Host "✅ GitHub Actions workflow found" -ForegroundColor Green
} else {
    $issues += "GitHub Actions workflow not found at .github/workflows/deploy-to-acr.yml"
}

# Check 4: env_sample.txt exists for reference
Write-Host "Checking environment template..." -ForegroundColor Yellow
if (Test-Path "src/env_sample.txt") {
    Write-Host "✅ Environment template found" -ForegroundColor Green
} else {
    $warnings += "env_sample.txt not found - consider creating one as a template"
}

# Check 5: No .env file in repository
Write-Host "Checking for sensitive files..." -ForegroundColor Yellow
if (Test-Path "src/.env") {
    $issues += "❌ SECURITY RISK: .env file found in src/ directory - this should not be committed!"
} else {
    Write-Host "✅ No .env file found in repository (good for security)" -ForegroundColor Green
}

# Check 6: Docker context (requirements.txt, etc.)
Write-Host "Checking Docker build context..." -ForegroundColor Yellow
if (Test-Path "src/requirements.txt") {
    Write-Host "✅ requirements.txt found" -ForegroundColor Green
} else {
    $warnings += "requirements.txt not found in src/ - Docker build may fail"
}

if (Test-Path "src/chat_app.py") {
    Write-Host "✅ Main application file found" -ForegroundColor Green
} else {
    $warnings += "chat_app.py not found - verify main application file exists"
}

# Check 7: Azure CLI availability
Write-Host "Checking Azure CLI..." -ForegroundColor Yellow
try {
    az --version | Out-Null
    Write-Host "✅ Azure CLI is available" -ForegroundColor Green
} catch {
    $warnings += "Azure CLI not found - needed for local testing and setup"
}

# Summary
Write-Host
Write-Host "📊 Validation Summary" -ForegroundColor Cyan
Write-Host "===================="

if ($issues.Count -eq 0) {
    Write-Host "✅ No critical issues found!" -ForegroundColor Green
} else {
    Write-Host "❌ Critical Issues Found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "   • $issue" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host
    Write-Host "⚠️  Warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "   • $warning" -ForegroundColor Yellow
    }
}

Write-Host
if ($issues.Count -eq 0) {
    Write-Host "🚀 Your setup is ready for GitHub Actions deployment!" -ForegroundColor Green
    Write-Host
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Set up GitHub secrets (run setup-github-actions.ps1)"
    Write-Host "2. Push your changes to trigger the workflow"
    Write-Host "3. Monitor the deployment in GitHub Actions"
} else {
    Write-Host "🔧 Please fix the critical issues before proceeding with deployment." -ForegroundColor Yellow
}

Write-Host