# Interior Design Agent - Workflow triggered on 2025-11-21 22:15:00
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential, AzureCliCredential
from azure.ai.agents.models import FunctionTool, ToolSet
from typing import Callable, Set, Any
from tools.imageCreationTool import create_image

# Load the prompt instructions for the interior design agent from a file
# path = r'prompts\InteriorDesignAgentPrompt.txt'
ID_PROMPT_TARGET = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'prompts', 'InteriorDesignAgentPrompt.txt')
with open(ID_PROMPT_TARGET, 'r', encoding='utf-8') as file:
    ID_PROMPT = file.read()

project_endpoint = os.environ["AZURE_AI_AGENT_ENDPOINT"]
agent_id = os.environ["interior_designer"]


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

# Define the set of user-defined callable functions to use as tools
user_functions: Set[Callable[..., Any]] = {
    create_image
}

# Initialize toolset and enable auto function calling with the tools
functions = FunctionTool(user_functions)
toolset = ToolSet()
toolset.add(functions)
project_client.agents.enable_auto_function_calls(tools=functions)

 # Create the agent using a specific deployment, name, instructions, and toolset
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
            name="Zava Interior Design Agent",  # Name of the agent
            instructions=ID_PROMPT,  # Updated instructions for the agent
            # toolset=toolset
        )
        print(f"Updated agent, ID: {agent.id}")
    else:
        agent = project_client.agents.create_agent(
            model=os.environ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"],  # Model deployment name
            name="Zava Interior Design Agent",  # Name of the agent
            instructions=ID_PROMPT,  # Instructions for the agent
            # toolset=toolset
        )
        print(f"Created agent, ID: {agent.id}")