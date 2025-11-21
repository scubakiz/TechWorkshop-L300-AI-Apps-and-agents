#!/usr/bin/env python3
"""
Azure Authentication Diagnostic Script

This script helps diagnose authentication issues and provides recommendations
for the IS_LOCAL_AUTH environment variable setting.
"""
import os
import subprocess
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def check_azure_cli():
    """Check if Azure CLI is available"""
    try:
        # On Windows, need to handle shell properly
        import platform
        if platform.system() == "Windows":
            result = subprocess.run(['az', '--version'], 
                                  capture_output=True, text=True, timeout=10, shell=True)
        else:
            result = subprocess.run(['az', '--version'], 
                                  capture_output=True, text=True, timeout=10)
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return False

def check_environment():
    """Check current environment and provide recommendations"""
    print("=== Azure Authentication Diagnostic ===\n")
    
    # Check if we're in Azure (common Azure environment indicators)
    in_azure = any([
        os.getenv('WEBSITE_HOSTNAME'),  # Azure App Service
        os.getenv('CONTAINER_APP_NAME'),  # Azure Container Apps
        os.getenv('AKS_NODE_NAME'),  # Azure Kubernetes Service
        os.path.exists('/opt/microsoft'),  # Common Azure path
        os.getenv('MSI_ENDPOINT'),  # Managed Service Identity endpoint
    ])
    
    is_local_auth = os.getenv("IS_LOCAL_AUTH", "").lower()
    azure_cli_available = check_azure_cli()
    
    print(f"Environment Detection:")
    print(f"  Running in Azure: {'Yes' if in_azure else 'No'}")
    print(f"  Azure CLI Available: {'Yes' if azure_cli_available else 'No'}")
    print(f"  IS_LOCAL_AUTH: '{is_local_auth}' {'(not set)' if not is_local_auth else ''}")
    print()
    
    # Provide recommendations
    print("Recommendations:")
    
    if in_azure:
        if is_local_auth == "true":
            print("  ❌ ISSUE: IS_LOCAL_AUTH is set to 'true' but you're running in Azure")
            print("  ✅ FIX: Set IS_LOCAL_AUTH='false' or remove it entirely")
            print("  📝 This will use DefaultAzureCredential with managed identity")
        elif not is_local_auth or is_local_auth == "false":
            print("  ✅ GOOD: IS_LOCAL_AUTH is correctly configured for Azure deployment")
            print("  📝 Using DefaultAzureCredential with managed identity")
        else:
            print(f"  ⚠️  WARNING: Unexpected IS_LOCAL_AUTH value: '{is_local_auth}'")
            print("  ✅ RECOMMENDATION: Set IS_LOCAL_AUTH='false' or remove it")
    else:
        if is_local_auth == "true":
            if azure_cli_available:
                print("  ✅ GOOD: IS_LOCAL_AUTH is set for local development and Azure CLI is available")
                print("  📝 Using AzureCliCredential")
            else:
                print("  ❌ ISSUE: IS_LOCAL_AUTH='true' but Azure CLI is not available")
                print("  ✅ FIX: Install Azure CLI and run 'az login'")
                print("  🔄 OR: Set IS_LOCAL_AUTH='false' to use DefaultAzureCredential")
        elif not is_local_auth or is_local_auth == "false":
            print("  ℹ️  INFO: Using DefaultAzureCredential for local development")
            print("  💡 TIP: Set IS_LOCAL_AUTH='true' if you want to use Azure CLI credentials")
        else:
            print(f"  ⚠️  WARNING: Unexpected IS_LOCAL_AUTH value: '{is_local_auth}'")
            print("  ✅ RECOMMENDATION: Set IS_LOCAL_AUTH='true' for local or 'false' for Azure")
    
    print()
    
    # Environment variable suggestions
    if in_azure and is_local_auth == "true":
        print("Quick Fix for Azure Deployment:")
        print("  1. In Azure App Service: Go to Configuration > Application Settings")
        print("  2. Add/Update: IS_LOCAL_AUTH = false")
        print("  3. Save and restart the application")
        print()
        print("Or remove IS_LOCAL_AUTH entirely to use the default (false)")
    elif not in_azure and is_local_auth != "true" and azure_cli_available:
        print("Quick Fix for Local Development:")
        print("  1. Add to your .env file: IS_LOCAL_AUTH=true")
        print("  2. Or set environment variable: export IS_LOCAL_AUTH=true")
        print("  3. Ensure you're logged in: az login")

def main():
    """Main diagnostic function"""
    try:
        check_environment()
    except Exception as e:
        print(f"Error during diagnosis: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()