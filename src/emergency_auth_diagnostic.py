#!/usr/bin/env python3
"""
Emergency authentication diagnostic for Azure deployment
Run this script in the Azure environment to diagnose the authentication issue
"""
import os
import sys

def emergency_auth_diagnostic():
    """Comprehensive diagnostic for authentication issues"""
    print("=" * 60)
    print("EMERGENCY AZURE AUTHENTICATION DIAGNOSTIC")
    print("=" * 60)
    print()
    
    # 1. Environment Detection
    print("1. ENVIRONMENT DETECTION")
    print("-" * 30)
    
    azure_indicators = {
        "WEBSITE_HOSTNAME": os.getenv("WEBSITE_HOSTNAME"),
        "CONTAINER_APP_NAME": os.getenv("CONTAINER_APP_NAME"), 
        "AKS_NODE_NAME": os.getenv("AKS_NODE_NAME"),
        "MSI_ENDPOINT": os.getenv("MSI_ENDPOINT"),
        "IDENTITY_ENDPOINT": os.getenv("IDENTITY_ENDPOINT"),
        "/opt/microsoft exists": os.path.exists("/opt/microsoft"),
    }
    
    in_azure = any(azure_indicators.values())
    print(f"Running in Azure: {in_azure}")
    
    for key, value in azure_indicators.items():
        if value:
            print(f"  {key}: {value}")
    
    print()
    
    # 2. IS_LOCAL_AUTH Analysis
    print("2. IS_LOCAL_AUTH ANALYSIS")
    print("-" * 30)
    
    is_local_auth_raw = os.getenv("IS_LOCAL_AUTH")
    is_local_auth_default = os.getenv("IS_LOCAL_AUTH", "false")
    is_local_auth_bool = is_local_auth_default.lower() == "true"
    
    print(f"IS_LOCAL_AUTH (raw): {repr(is_local_auth_raw)}")
    print(f"IS_LOCAL_AUTH (with default): '{is_local_auth_default}'")
    print(f"IS_LOCAL_AUTH (boolean): {is_local_auth_bool}")
    print()
    
    # 3. Expected vs Actual Behavior
    print("3. EXPECTED BEHAVIOR")
    print("-" * 30)
    
    if in_azure and not is_local_auth_bool:
        print("✅ CORRECT: Should use DefaultAzureCredential")
    elif in_azure and is_local_auth_bool:
        print("❌ PROBLEM: IS_LOCAL_AUTH=true in Azure - should be false or unset")
        print("   SOLUTION: Remove IS_LOCAL_AUTH or set to 'false' in Azure App Settings")
    elif not in_azure and is_local_auth_bool:
        print("✅ CORRECT: Should use AzureCliCredential locally")
    else:
        print("ℹ️  Local environment using DefaultAzureCredential")
    
    print()
    
    # 4. Test Azure CLI availability (if IS_LOCAL_AUTH=true)
    if is_local_auth_bool:
        print("4. AZURE CLI TEST (since IS_LOCAL_AUTH=true)")
        print("-" * 40)
        
        try:
            import subprocess
            result = subprocess.run(['az', '--version'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                print("✅ Azure CLI is available")
            else:
                print("❌ Azure CLI command failed")
                print(f"   Error: {result.stderr}")
        except FileNotFoundError:
            print("❌ Azure CLI not found in PATH")
            print("   This explains the 'Azure CLI not found on path' error!")
        except Exception as e:
            print(f"❌ Azure CLI test failed: {e}")
        
        print()
    
    # 5. Credential Testing
    print("5. CREDENTIAL TESTING")
    print("-" * 25)
    
    try:
        from azure.identity import DefaultAzureCredential, AzureCliCredential
        from azure.identity._exceptions import CredentialUnavailableError
        
        if is_local_auth_bool:
            print("Testing AzureCliCredential...")
            try:
                cred = AzureCliCredential()
                token = cred.get_token("https://cognitiveservices.azure.com/.default")
                print("✅ AzureCliCredential: SUCCESS")
            except CredentialUnavailableError as e:
                print(f"❌ AzureCliCredential: {e}")
                print("   This is the root cause of your error!")
            except Exception as e:
                print(f"❌ AzureCliCredential: {e}")
        
        print("Testing DefaultAzureCredential...")
        try:
            cred = DefaultAzureCredential()
            token = cred.get_token("https://cognitiveservices.azure.com/.default")
            print("✅ DefaultAzureCredential: SUCCESS")
        except Exception as e:
            print(f"❌ DefaultAzureCredential: {e}")
            
    except ImportError as e:
        print(f"❌ Cannot import Azure Identity libraries: {e}")
    
    print()
    
    # 6. Recommendations
    print("6. RECOMMENDATIONS")
    print("-" * 20)
    
    if in_azure and is_local_auth_bool:
        print("🚨 IMMEDIATE FIX NEEDED:")
        print("1. In Azure App Service: Configuration > Application Settings")
        print("2. Remove 'IS_LOCAL_AUTH' setting entirely")
        print("   OR set 'IS_LOCAL_AUTH = false'")
        print("3. Save and restart the application")
        print()
        print("This will force the use of DefaultAzureCredential with managed identity")
        
    elif in_azure and not is_local_auth_bool:
        print("✅ Configuration appears correct")
        print("If still failing, check managed identity permissions")
        
    else:
        print("ℹ️  This appears to be a local development environment")
        if is_local_auth_bool:
            print("Ensure Azure CLI is installed and you're logged in: az login")
        else:
            print("Consider setting IS_LOCAL_AUTH=true for local development")
    
    print()
    print("=" * 60)

if __name__ == "__main__":
    emergency_auth_diagnostic()