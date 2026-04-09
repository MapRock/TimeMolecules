
## Installation

### 1. Prerequisites

- **Python 3.10 or higher**
- **Git**
- **Ollama** (recommended for local/private use) → [Download & install from ollama.com](https://ollama.com/)
- (Optional) OpenAI API key if you prefer using GPT models instead of local LLMs
- On Windows: Microsoft ODBC Driver for SQL Server (only needed if you want to pull metadata directly from your TimeSolution SQL Server database)

### 2. Clone the Repository & Navigate to the Tutorial

```bash
git clone https://github.com/MapRock/TimeMolecules.git
cd TimeMolecules/tutorials/ai_agent_skills
```

### 3. Install Python Dependencies

```bash
pip install -r requirements.txt
```

> **Note**: The current `requirements.txt` only covers the UI script. The embedding script also needs `pandas`, `pyodbc`, and `requests`.  
> You can install everything with one command:

```bash
pip install qdrant-client ollama openai>=0.28.0,<1.0.0 python-dotenv pandas pyodbc requests
```

### 4. Install Required Ollama Models (if using Ollama)

```bash
ollama pull nomic-embed-text          # embedding model
ollama pull llama3.2                  # chat model (you can change this later)
```

### 5. Create the `.env` File

Copy the example below into a new file named **`.env`** in this folder (`tutorials/ai_agent_skills`):

```env
# LLM choice (ollama or openai)
LLM=ollama

# === Ollama Settings ===
OLLAMA_EMBED_MODEL=nomic-embed-text
OLLAMA_CHAT_MODEL=llama3.2
OLLAMA_CTX=8192
OLLAMA_HOST=                     # leave empty for default localhost:11434

# === OpenAI Settings (only used if LLM=openai) ===
# OPENAI_API_KEY=sk-your-key-here
# CHATGPT_MODEL=gpt-4o-mini
# CHATGPT_MAX_RESPONSE_TOKENS=500

# === Qdrant Settings ===
QDRANT_COLLECTION_NAME=time_molecules_directory
QDRANT_PATH=c:/MapRock/TimeMolecules/qdrant_data_ollama   # ← change to your preferred folder

# === Search Settings ===
RESULTS_LIMIT=8
```

> Adjust `QDRANT_PATH` to a folder you have write access to.

### 6. Build the Vector Database (Run Once)

**This step is required** — it creates the Qdrant collection with all TimeSolution objects and LLM prompt documents.

```bash
python time_molecules_embeddings.py
```

The script will:
- Pull metadata (from SQL Server if configured, otherwise from the public CSV on GitHub)
- Generate embeddings
- Create and populate the Qdrant collection
- Also ingest all LLM prompt files from the `docs/llm_prompts` folder

### 7. Run the AI Agent Demo

```bash
python time_molecules_agent_demo_.py
```

A Tkinter window will open. You can now type natural-language questions about your TimeSolution database objects and get semantic search results + LLM summaries.

---

**You're all set!**  
The first run of the embedding script may take a minute or two (embedding ~200–300 objects).

Any questions or issues? Just open an issue in the repo.
