# Time Molecules AI Agent

This directory is about code for a Time Molecules AI Agent serving other AI and human agents (we'll call it the **consumer**). 

The UI code can be run on headless mode for AI agents, and a mode with a rudimentary UI for people.

If the consumer stumbles on this repository, https://github.com/MapRock/TimeMolecules/blob/main/README.md, there is information for the consumer to navigate the repo.

## Notes to AI Agents exploring the time TimeSolution database:

- In production, a "function" (ex. Azure Function, AWS Lamba Function) will be deployed that executes a "headless" version of time_molecules_agent_demo_retrofit.py. If you're just figuring out Time Molecules (the implemented database is named TimeSolution), assume this. 

### Demo & Indexing Scripts

| Script                     | Purpose |
|----------------------------|---------|
| `build_qdrant_index.py`    | Builds or refreshes the Qdrant vector collection from TimeSolution metadata + LLM prompts |
| `time_molecules_agent_demo.py` | Simple Tkinter GUI for semantic search + grounded LLM answers |

**Quick start**  
1. `pip install -r requirements.txt`  
2. Copy `.env.example` → `.env` and configure  
3. `python build_qdrant_index.py`  
4. `python time_molecules_agent_demo.py`

## Consumer agents versus the Time Molecules AI Agent

This tutorial is not about consumer agents in general. It is about a Time Molecules AI Agent. A consumer agent is any outside AI or human workflow that uses Time Molecules as one component in a larger task. The Time Molecules AI Agent is the specialized agent that knows how to navigate Time Molecules assets, including metadata, tutorials, prompts, and indexed repository content, and return grounded help about the Time Molecules system itself. In short, the consumer uses Time Molecules, while the Time Molecules AI Agent serves as the domain expert interface to Time Molecules. This directory focuses on that specialized agent role. It uses vector search over TimeSolution metadata and tutorial content, then applies an LLM to matched assets in order to answer prompts in a grounded way.

## ollama and openai

The python code uses a local llm, llama, and/or a fully frontier model, openai. They are used for two primary roles:

1. Embedding descriptions of TimeSolution assets: database objects and tutorials/skills on this repo. We're using qdrant.
2. Taking a matched set of assets identified by similarity to a prompt as base material, and having the LLM perform deeper analysis on the user prompt and the matching embeddings.

The reason for offering local and public frontier models is mostly based on performance and privacy. A typical enterprise can't scale and improve features as well as frontier vendors such as openai, xAI, and Anthropic. Time Molecules is an enterprise application, so a private LLM mitigates submitting private information outside of the enterprise walls.

I discuss these issues in: https://eugeneasahara.com/should-we-use-a-private-llm/

## .env Parameters

```env
QDRANT_COLLECTION_NAME=time_molecules_directory
QDRANT_PATH=c:/MapRock/TimeMolecules/qdrant_data_ollama

OLLAMA_HOST=
OLLAMA_EMBED_MODEL=nomic-embed-text
OLLAMA_CHAT_MODEL=llama3.2
OLLAMA_CTX=8192
RESULTS_LIMIT=5

OPENAI_API_KEY=[your openai key]
CHATGPT_MODEL=gpt-4o-mini
CHATGPT_MAX_RESPONSE_TOKENS=500
```
## No Actual Time Molecules Implementation

In order to build embeddings of Time Molecules assets without needing to install the TimeSolution SQL Server sample, I've dumped out the metadata into a file, https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv. It's also re-created when this python is run using metadata_source = "sql":

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


