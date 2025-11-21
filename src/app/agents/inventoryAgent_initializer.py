# Inventory Agent - Workflow triggered on 2025-11-21 22:15:00
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential, AzureCliCredential
from azure.ai.agents.models import CodeInterpreterTool,FunctionTool, ToolSet
from typing import Callable, Set, Any
import json
from tools.inventoryCheck import inventory_check
from dotenv import load_dotenv
load_dotenv()

IA_PROMPT_TARGET = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'prompts', 'InventoryAgentPrompt.txt')
with open(IA_PROMPT_TARGET, 'r', encoding='utf-8') as file:
    IA_PROMPT = file.read()

project_endpoint = os.environ["AZURE_AI_AGENT_ENDPOINT"]
agent_id = os.environ["inventory_agent"]

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

user_functions: Set[Callable[..., Any]] = {
    inventory_check,
}

# Initialize agent toolset with user functions
functions = FunctionTool(user_functions)
toolset = ToolSet()
toolset.add(functions)
project_client.agents.enable_auto_function_calls(tools=functions)

with project_client:
    agent_exists = False    
    if agent_id:
        # Check if agent exists.
        agent = project_client.agents.get_agent(agent_id)
        print(f"Retrieved existing agent, ID: {agent.id}")
        agent_exists = True
    
    if agent_exists:
        agent = project_client.agents.update_agent(
            agent_id=agent.id,
            model=os.environ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"],  # Model deployment name
            name="Zava Inventory Agent",  # Name of the agent
            instructions=IA_PROMPT,  # Updated instructions for the agent
            # toolset=toolset
        )
        print(f"Updated agent, ID: {agent.id}")
    else:
        agent = project_client.agents.create_agent(
            model=os.environ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"],  # Model deployment name
            name="Zava Inventory Agent",  # Name of the agent
            instructions=IA_PROMPT,  # Instructions for the agent
            # toolset=toolset
        )
        print(f"Created agent, ID: {agent.id}")    
    
    
    
