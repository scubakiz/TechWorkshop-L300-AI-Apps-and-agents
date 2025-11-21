import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential, AzureCliCredential
from azure.ai.agents.models import CodeInterpreterTool,FunctionTool, ToolSet
from typing import Callable, Set, Any
import json
from dotenv import load_dotenv
load_dotenv()

CORA_PROMPT_TARGET = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'prompts', 'ShopperAgentPrompt.txt')
with open(CORA_PROMPT_TARGET, 'r', encoding='utf-8') as file:
    CORA_PROMPT = file.read()

project_endpoint = os.environ["AZURE_AI_AGENT_ENDPOINT"]

# Choose authentication method based on IS_LOCAL_AUTH environment variable
is_local_auth = os.getenv("IS_LOCAL_AUTH", "false").lower() == "true"

if is_local_auth:
    # Use AzureCliCredential for local development
    try:
        from azure.identity._exceptions import CredentialUnavailableError
        credential = AzureCliCredential()
        # Test the credential by attempting to get a token
        credential.get_token("https://cognitiveservices.azure.com/.default")
        project_client = AIProjectClient(
            endpoint=project_endpoint,
            credential=credential,
        )
        print("Using AzureCliCredential for local authentication")
    except (Exception, CredentialUnavailableError) as e:
        print(f"AzureCliCredential failed: {e}. Falling back to DefaultAzureCredential")
        project_client = AIProjectClient(
            endpoint=project_endpoint,
            credential=DefaultAzureCredential(),
        )
else:
    # Use DefaultAzureCredential for Azure deployment
    print("Using DefaultAzureCredential for Azure deployment authentication")
    project_client = AIProjectClient(
        endpoint=project_endpoint,
        credential=DefaultAzureCredential(),
    )


with project_client:
    agent = project_client.agents.create_agent(
        model=os.environ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"],  # Model deployment name
        name="Cora",  # Name of the agent
        instructions=CORA_PROMPT,  # Instructions for the agent
        # toolset=toolset
    )
    print(f"Created agent, ID: {agent.id}")
