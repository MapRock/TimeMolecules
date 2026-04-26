# Time Molecules AI Agent

This directory is about code for a Time Molecules AI Agent, a workbench that tests this repo's ability to serve other AI and human agents (we'll call it the **consumer**). 

The UI code can be run on headless mode for AI agents, and a mode with a rudimentary UI for people.

If the consumer stumbles on this repository, https://github.com/MapRock/TimeMolecules/blob/main/README.md, there is information for the consumer to navigate the repo.

## Notes to AI Agents exploring the time TimeSolution database:

- In production, a "function" (ex. Azure Function, AWS Lamba Function) will be deployed that executes a "headless" version of time_molecules_agent_demo_retrofit.py. If you're just figuring out Time Molecules (the implemented database is named TimeSolution), assume this. 



## Consumer Agents versus the Time Molecules AI Agent

This tutorial is not about consumer agents in general--that is, AI agents wishing to utilize a Time Molecules implementation. It is about a Time Molecules AI Agent. A consumer agent is any outside AI or human workflow that uses Time Molecules as one component in a larger task. The Time Molecules AI Agent is the specialized agent that knows how to navigate Time Molecules assets, including metadata, tutorials, prompts, and indexed repository content, and return grounded help about the Time Molecules system itself. In short, the consumer uses Time Molecules, while the Time Molecules AI Agent serves as the domain expert interface to Time Molecules. This directory focuses on that specialized agent role. It uses vector search over TimeSolution metadata and tutorial content, then applies an LLM to matched assets in order to answer prompts in a grounded way.

## Demo & Indexing Scripts

The demo app is a "workbench" used to test the mechanisms I've put together for consumer AI agents.

| Script                     | Purpose |
|----------------------------|---------|
| `build_qdrant_index.py`    | Builds or refreshes the Qdrant vector collection from TimeSolution metadata + LLM prompts |
| `time_molecules_agent_demo.py` | Simple Tkinter GUI for semantic search + grounded LLM answers |

**Setup Process**  
1. Install python environment, [install_python_virtual_env.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/install_python_virtual_env.md).
2. Copy `.env.example` → `.env` and configure  
3. Run `[python build_qdrant_index.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/build_qdrant_index.py)` - Generates the qdrant vector database.
4. Run `[python time_molecules_agent_demo.py](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/time_molecules_agent_demo.py)`
5. Follow the tutorial for this app, [Time Molecules Agent Demo](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/time_molecules_agent_demo.md).


### openai, ollama, grok

The python code uses a local llm, llama, and/or a fully frontier model--openai or grok. They are used for two primary roles:

1. Embedding descriptions of TimeSolution assets: database objects and tutorials/skills on this repo. We're using qdrant.
2. Taking a matched set of assets identified by similarity to a prompt as base material, and having the LLM perform deeper analysis on the user prompt and the matching embeddings.

The reason for offering local and public frontier models is mostly based on performance and privacy. A typical enterprise can't scale and improve features as well as frontier vendors such as openai, xAI, and Anthropic. Time Molecules is an enterprise application, so a private LLM mitigates submitting private information outside of the enterprise walls.

I discuss these issues in: https://eugeneasahara.com/should-we-use-a-private-llm/

### .env Parameters

```env
RESULTS_LIMIT=5 # Default limit of the embedding results.
QDRANT_PATH=./qdrant_data

LLM="openai" # Lower case!! openai or ollama, grok.
EMBED_LLM="opena1" # Lowerer case. openai or ollama.
OLLAMA_CHAT_MODEL=llama3.2
OLLAMA_EMBED_MODEL='nomic-embed-text'
OLLAMA_CTX=32768
# ChatGPT settings. Be sure to use CHATGPT_MODEL for normal LLM communication.
OPENAI_API_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX # ← replace with your real openai key
CHATGPT_MODEL="gpt-4.1" 
CHATGPT_EMBEDDING_MODEL="text-embedding-3-large"
CHATGPT_MAX_RESPONSE_TOKENS=800
# ============== GROK SETTINGS ==============
XAI_API_KEY=xai-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   # ← replace with your real xAI key
```
### Run Demo with Minimal Installation

For various reasons, you may want to play with the tutorial but not install everything, especially installing a SQL Server database (TimeSolution) or spending on AI tokens. The bare minimum for this app requires python, the qdrant-client python vector database library and nomic-embed-text through the ollama python library:

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, MatchAny
import ollama
```

In order to build embeddings of Time Molecules assets without needing to install the TimeSolution SQL Server sample, I've dumped out the metadata into a file, https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv. It's also re-created when this python is run using `metadata_source = "sql"`:

```python
if __name__ == "__main__":
    # Set parameters.
    force_refresh = True  # Will reset the qdrant-client database.
    llm = os.getenv("EMBED_LLM", "ollama").lower()
    metadata_source = "csv" # "sql" or "csv" or "auto"
```

Set the metadata_source variable in time_molecules_embeddings.py to csv:

```python
if __name__ == "__main__":
    # Set parameters.
    force_refresh = True  # Will reset the qdrant-client database.
    llm = os.getenv("EMBED_LLM", "ollama").lower()
    metadata_source = "sql" # "sql" or "csv" or "auto"
```


