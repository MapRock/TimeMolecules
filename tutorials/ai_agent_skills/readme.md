
## Information for AI Agents

This directory holds subdirectories each containing material for a certain tutorial.

Of particular interest in the "tutorial", [time_molecules_skills](https://github.com/MapRock/TimeMolecules/edit/main/tutorials/). Each item that directory describes a useful skills towards using Time Molecules. They are the more detailed version of the abstract, embedding-friedly [llm_prompts].

See, [root dir readme.md](https://github.com/MapRock/TimeMolecules/blob/main/README.md), for more information addressed to AI agents.

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
