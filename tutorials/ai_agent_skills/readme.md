# Time Molecules AI Agent

This directory is about code for a Time Molecules AI Agent serving other AI and human agents.

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
