# Python Virtual Environment Setup for TimeMolecules Tutorials

## Introduction

Welcome! This guide walks you through setting up a clean **Python virtual environment** on Windows so you can run the TimeMolecules tutorial code — especially the **AI Agent Skills demo** located in [tutorials/ai_agent_skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills). The target audience are people who simply wish to explore concepts and capabilities about Time Molecules before purchasing the [Time Molecules](https://technicspub.com/time-molecules/) book for a fuller, foundational understanding.

**Note** that for readers of the <i>[Time Molecules](https://technicspub.com/time-molecules/)</i> book, the installation is a little bit more complicated. Please refer to [install_timemolecules_dev_env.md](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.md) for the install instructions for book readers. **Or better yet**, procure the [Azure Virtual Machine](https://github.com/MapRock/TimeMolecules/blob/main/docs/procure_time_molecules_vm.md) I created.

---

## Prerequisites

- Windows 10 or 11


### Key Design Decisions (so you know why it’s built this way)
- **Python virtual environment is mandatory** (never optional).
- **SQL Server is optional** → the build script falls back to a [public CSV snapshot](https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv). You can explore everything without installing SQL Server.
- **Ollama is strongly recommended** (free, private, local LLM – no API keys or costs).
- **Visual Studio Code** is the recommended editor (makes running Python trivial).
- **Azure VM** is an excellent clean-test option (I tested it myself), but it costs money → use only when you want a 100% fresh Windows environment.
- Everything runs in one folder: [ai_agent_skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills)

---

### Deployment Options
- **Local machine** (no Azure cost) → Go to Step 1.  
- **Azure Windows VM** (a little cost, but less risky) → see [setup_azure_vm_for_testing_time_molecules.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md) for instructions on procuring an Azure Windows VM. After installing the Windows VM, go to Step 1.

---

## Step 1:  Get the code

Either clone the repo:

```bash
git clone https://github.com/MapRock/TimeMolecules.git
cd TimeMolecules
````

Or download the ZIP from GitHub and extract it, then open a terminal in the extracted `TimeMolecules` folder.

1. Open the repository page in your web browser.
2. Go to the main page of the repository:
   `https://github.com/MapRock/TimeMolecules`
3. Above the list of files, click the **Code** button.
4. In the menu that opens, click **Download ZIP**.
5. Save the ZIP file to your computer.
6. After the download finishes, extract the ZIP to a folder such as:

## Step 2: Install the Base Tools (do this once)

1. **Python 3.11 or 3.12** (recommended)  
   → https://www.python.org/downloads/  
   **Important:** On Windows, **check “Add python.exe to PATH”** during install.

2. **Git**  
   → https://git-scm.com/downloads

3. **Visual Studio Code** (strongly recommended)  
   → https://code.visualstudio.com/  
   After installing, open VS Code → Extensions (Ctrl+Shift+X) → install the official **Python** extension by Microsoft.

4. **Ollama** (local LLM – highly recommended)  
   - Windows PowerShell (run as Administrator):  
     ```powershell
     irm https://ollama.com/install.ps1 | iex
     ```
   - Or download from https://ollama.com/download  
   After Ollama is installed, open a terminal and run:
     ```powershell
     ollama pull nomic-embed-text     # embedding model
     ollama pull llama3.2             # chat model (you can swap later)
     ```

5. **Optional but nice: Microsoft ODBC Driver 18 for SQL Server** (only if you want to use your own SQL Server later)  
   → https://aka.ms/downloadmsodbcsql

---

## Step 3: Get the Code

Open PowerShell (or Git Bash / terminal) and run:

```powershell
git clone https://github.com/MapRock/TimeMolecules.git
cd TimeMolecules\tutorials\ai_agent_skills
```

(If you prefer downloading a ZIP instead of Git, download the repo ZIP, extract it, and navigate into the ai_agent_skills folder.)

---

## Step 4: Create the Python Virtual Environment (do this once)

**Always** use a venv for this tutorial.

In the `ai_agent_skills` folder, run:

```powershell
python -m venv .venv
```

**Activate it** (you must do this every new session):

```powershell
.\.venv\Scripts\Activate.ps1
```

You should see `(.venv)` at the start of your prompt.

**If PowerShell complains about execution policy** (first time only):

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then activate again.

---

## Step 5: Install Python Packages

While the venv is active:

```powershell
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install pandas pyodbc requests   # extra packages the build script may need
```

---

## Step 6: Create the `.env` File (very important)

Create a file named exactly `.env` (no .txt) **inside the `ai_agent_skills` folder**.

Copy-paste the following (you can edit later):

```env
# LLM choice (ollama or openai)
LLM=ollama

# === Ollama Settings ===
OLLAMA_EMBED_MODEL=nomic-embed-text
OLLAMA_CHAT_MODEL=llama3.2
OLLAMA_CTX=8192
OLLAMA_HOST=                     # leave empty for default localhost:11434

# === OpenAI Settings (only if you want to use GPT instead) ===
# OPENAI_API_KEY=sk-your-key-here
# CHATGPT_MODEL=gpt-4o-mini

# === Qdrant Settings ===
QDRANT_COLLECTION_NAME=time_molecules_directory
QDRANT_PATH=C:/MapRock/TimeMolecules/qdrant_data_ollama   # change if you want

# === Search Settings ===
RESULTS_LIMIT=8
```

**Security note**: Never commit `.env` to GitHub. Add `.env` to `.gitignore` if you ever push changes.

---

## Step 7: Build the Vector Database (run once)

```powershell
python build_qdrant_index.py
```

This script:
- Pulls metadata (from SQL Server **if** configured, otherwise from a [public CSV on GitHub](https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv))
- Creates embeddings with Ollama
- Stores everything in a local Qdrant collection

First run takes 1–3 minutes (embedding ~200–300 objects). Subsequent runs are fast.

---

## Step 8: Run the AI Agent Demo

```powershell
python time_molecules_agent_demo.py
```

A nice Tkinter GUI window opens. Type natural-language questions about TimeSolution objects and watch the agent answer.

**Lightweight / zero-dependency option** (no Qdrant, no SQL, no build step):
- Download the pre-built JSON file from the OneDrive link in `install_ai_agent_skills.md` (or just try the script – it has fallback logic).
- Run: `python time_molecules_data_json_ui.py`

---

## Step 9: Install SQL Server Developer Edition (trade-offs explained)

**You do NOT need SQL Server** to explore the tutorial. The build script falls back gracefully to a [public CSV snapshot](https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv).

**When you might want it**:
- You already have or plan to restore the TimeSolution database.
- You want live metadata instead of the snapshot.

**Install steps (Windows)**:
1. Go to https://www.microsoft.com/en-us/sql-server/sql-server-downloads
2. Download **Developer Edition** (free)
3. Run the installer → choose **Basic** installation
4. Note your instance name (usually `MSSQLSERVER`)
5. Install the ODBC Driver 18 (link in Step 1)

The demo will automatically detect and use it if configured in `.env`.

---

## Visual Studio Code Tips (highly recommended)

1. Open the `[ai_agent_skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills)` folder in VS Code (`File → Open Folder`).
2. Press `Ctrl+Shift+P` → type **Python: Select Interpreter** → choose the one inside `.venv\Scripts\python.exe`.
3. Open any `.py` file → click the Run button or right-click → “Run Python File in Terminal”.

---

## Common Problems & Fixes

- **“.env not found”** → make sure it’s in the `ai_agent_skills` (not one level up).
- **ODBC / SQL connection errors** → install Microsoft ODBC Driver 18.
- **Ollama not responding** → make sure `ollama` is running in the background (it starts automatically after install).
- **Venv not active** → you should see `(.venv)` in the prompt.
- **First build is slow** → normal.

---

## Next Steps & Where to Go From Here

- Read `[time_molecules_agent_demo.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/time_molecules_agent_demo.md)` for how to use the demo.
- If you later buy the book and want the full dev environment (SQL restore, Neo4j, etc.), use `docs/install_timemolecules_dev_env.md`.

You now have a **bullet-proof**, self-contained setup that works for curious explorers, AI agents, and clean testing on Azure.

Enjoy exploring TimeMolecules!  
Any questions or issues → just open an issue on the repo or ask in the demo itself.
