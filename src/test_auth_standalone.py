#!/usr/bin/env python3
"""
Standalone authentication test for Azure AI Agents
This script tests authentication independently of the main application
"""
import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_authentication():
    """Test authentication methods"""
    print("=== Azure AI Agent Authentication Test ===")
    print()
    
    # Check environment variables
    project_endpoint = os.getenv("AZURE_AI_AGENT_ENDPOINT")
    is_local_auth_env = os.getenv("IS_LOCAL_AUTH", "false")
    is_local_auth = is_local_auth_env.lower() == "true"
    
    print(f"Project Endpoint: {project_endpoint}")
    print(f"IS_LOCAL_AUTH: '{is_local_auth_env}'")
    print(f"Using local auth: {is_local_auth}")
    print()
    
    if not project_endpoint:
        print("❌ ERROR: AZURE_AI_AGENT_ENDPOINT is not set")
        return False
    
    # Import Azure libraries
    try:
        from azure.ai.projects import AIProjectClient
        from azure.identity import DefaultAzureCredential, AzureCliCredential
        from azure.identity._exceptions import CredentialUnavailableError
    except ImportError as e:
        print(f"❌ ERROR: Failed to import Azure libraries: {e}")
        return False
    
    # Test authentication
    project_client = None
    
    if is_local_auth:
        print("🔍 Testing AzureCliCredential...")
        try:
            credential = AzureCliCredential()
            # Test the credential
            token = credential.get_token("https://cognitiveservices.azure.com/.default")
            print(f"✅ AzureCliCredential token obtained: {token.token[:20]}...")
            
            project_client = AIProjectClient(
                endpoint=project_endpoint,
                credential=credential,
            )
            print("✅ AIProjectClient created with AzureCliCredential")
            
        except (Exception, CredentialUnavailableError) as e:
            print(f"❌ AzureCliCredential failed: {e}")
            print("🔄 Falling back to DefaultAzureCredential...")
            
            try:
                credential = DefaultAzureCredential()
                token = credential.get_token("https://cognitiveservices.azure.com/.default")
                print(f"✅ DefaultAzureCredential token obtained: {token.token[:20]}...")
                
                project_client = AIProjectClient(
                    endpoint=project_endpoint,
                    credential=credential,
                )
                print("✅ AIProjectClient created with DefaultAzureCredential (fallback)")
                
            except Exception as e2:
                print(f"❌ DefaultAzureCredential also failed: {e2}")
                return False
    else:
        print("🔍 Testing DefaultAzureCredential...")
        try:
            credential = DefaultAzureCredential()
            token = credential.get_token("https://cognitiveservices.azure.com/.default")
            print(f"✅ DefaultAzureCredential token obtained: {token.token[:20]}...")
            
            project_client = AIProjectClient(
                endpoint=project_endpoint,
                credential=credential,
            )
            print("✅ AIProjectClient created with DefaultAzureCredential")
            
        except Exception as e:
            print(f"❌ DefaultAzureCredential failed: {e}")
            return False
    
    # Test API call
    if project_client:
        print()
        print("🔍 Testing API call (create thread)...")
        try:
            test_thread = project_client.agents.threads.create()
            print(f"✅ Test thread created successfully: {test_thread.id}")
            
            # Clean up
            project_client.agents.threads.delete(test_thread.id)
            print("✅ Test thread deleted successfully")
            
            print()
            print("🎉 ALL TESTS PASSED - Authentication is working correctly!")
            return True
            
        except Exception as e:
            print(f"❌ API call failed: {e}")
            print("This indicates authentication succeeded but API access failed")
            return False
    
    return False

if __name__ == "__main__":
    success = test_authentication()
    sys.exit(0 if success else 1)