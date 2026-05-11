
# Time Molecules Windows VM Setup

This guide explains how to set up a Windows VM for the Time Molecules tutorials and AI Agent Skills demo.

There are two intended paths:

1. **Preconfigured Time Molecules Demo VM**  
   Recommended for most readers. The VM should already contain SQL Server, SSMS, the restored `TimeSolution` database, Python 3.12, Visual Studio Code, the Python virtual environment, requirements, Qdrant data, and the demo app.

2. **Manual VM rebuild**  
   Use this if you are rebuilding the demo VM, testing the install from scratch, or setting up Time Molecules on your own Windows machine.

---

## Recommended reader path: preconfigured VM

The reader VM already includes:

- Windows
- SQL Server
- SQL Server Management Studio, or SSMS
- restored `TimeSolution` database
- `C:\MapRock\TimeMolecules`
- Python 3.12
- Visual Studio Code
- `C:\MapRock\TimeMolecules\tutorials\.venv`
- packages from `C:\MapRock\TimeMolecules\tutorials\requirements.txt`
- optional Ollama runtime and local models
- built Qdrant vector index
- shortcuts for opening the README, configuring `.env`, and running the agent demo

The reader should only need to add their own OpenAI API key here:

```text
C:\MapRock\TimeMolecules\tutorials\.env
````

Minimum `.env`:

```text
OPENAI_API_KEY=your_openai_key_here
```

Then run:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
.\.venv\Scripts\python.exe ai_agent_skills\time_molecules_agent_demo.py
```

---

# Manual VM rebuild

## Step 1: Install SQL Server

Install SQL Server first. Time Molecules uses the restored `TimeSolution` database as the main demo database.

For a demo VM, SQL Server Developer Edition is usually the right choice because it includes SQL Server features for development and demonstration use. Download SQL Server from Microsoft’s SQL Server downloads page. ([Microsoft][1])

Suggested installation choices:

```text
Edition: SQL Server Developer
Instance: default instance, if possible
Authentication: Windows Authentication is simplest for a local demo VM
Features: Database Engine Services
```

For a reader/demo VM, keep the setup simple. Avoid custom instance names unless you really need them.

After installing SQL Server, confirm the SQL Server service is running.

---

## Step 2: Install SQL Server Management Studio

Install SQL Server Management Studio, commonly called SSMS. SSMS is the normal graphical tool for connecting to SQL Server, restoring `.bak` files, browsing databases, and running SQL scripts. Microsoft documents SSMS as the tool for connecting to and querying SQL Server and related SQL platforms. ([Microsoft Learn][2])

Install SSMS from Microsoft’s SSMS install page. ([Microsoft Learn][3])

After installation:

```text
Start Menu
→ SQL Server Management Studio
→ Connect to local SQL Server
```

For a default local SQL Server instance, the server name is usually one of:

```text
localhost
.
(local)
```

If you installed a named instance, use:

```text
localhost\InstanceName
```

---

## Step 3: Download TimeSolution.bak

The database backup is not stored in GitHub because it is large.

Download:

```text
TimeSolution.bak
```

from the OneDrive link provided with the tutorial materials.

Recommended location:

```text
C:\MapRock\Backups\TimeSolution.bak
```

Create the folder if needed:

```powershell
mkdir C:\MapRock\Backups
```

---

## Step 4: Restore TimeSolution in SSMS

Open SSMS.

Connect to the local SQL Server instance.

Restore the database:

```text
Object Explorer
→ right-click Databases
→ Restore Database...
→ Source: Device
→ select C:\MapRock\Backups\TimeSolution.bak
→ Database: TimeSolution
→ OK
```

After restore, confirm this database exists:

```text
Databases
→ TimeSolution
```

Run a simple test query in SSMS:

```sql
USE TimeSolution;
GO

SELECT DB_NAME() AS CurrentDatabase;
```

Expected:

```text
TimeSolution
```

If the restore complains about file paths, use the SSMS restore dialog’s **Files** page and change the data/log file paths to valid SQL Server data locations on the VM.

---

## Step 5: Install Git

Install Git from:

```text
https://git-scm.com/downloads
```

Then open PowerShell and create the working folder:

```powershell
mkdir C:\MapRock
cd C:\MapRock
```

Clone the repository:

```powershell
git clone https://github.com/MapRock/TimeMolecules.git
```

Expected repo path:

```text
C:\MapRock\TimeMolecules
```

---

## Step 6: Install Python 3.12

Install Python 3.12 from the official Python site. ([Python.org][4])

During install, select:

```text
Add python.exe to PATH
```

Verify from PowerShell:

```powershell
py -3.12 --version
```

Expected:

```text
Python 3.12.x
```

---

## Step 7: Install Visual Studio Code

Install Visual Studio Code from the official VS Code site:

```text
https://code.visualstudio.com/
```

Install the Microsoft Python extension:

```text
VS Code
→ Extensions
→ search Python
→ install Python by Microsoft
```

Open the tutorials folder in VS Code:

```text
File
→ Open Folder
→ C:\MapRock\TimeMolecules\tutorials
```

The tutorials folder is the correct working folder because it contains:

```text
.venv
.env
requirements.txt
ai_agent_skills
```

---

## Step 8: Create the Python virtual environment

The virtual environment belongs under the `tutorials` folder:

```text
C:\MapRock\TimeMolecules\tutorials\.venv
```

From PowerShell:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
py -3.12 -m venv .venv
```

Activate it:

```powershell
.\.venv\Scripts\Activate.ps1
```

If activation is blocked:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\.venv\Scripts\Activate.ps1
```

Activation is optional. You can always run Python directly:

```powershell
.\.venv\Scripts\python.exe --version
```

---

## Step 9: Install Python requirements

The requirements file belongs here:

```text
C:\MapRock\TimeMolecules\tutorials\requirements.txt
```

Install packages:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

This installs the Python packages used by the tutorial app.

If `requirements.txt` includes the Python `ollama` package, that only installs the Python client. It does not install the Ollama Windows runtime.

---

## Step 10: Create the .env file

Create:

```text
C:\MapRock\TimeMolecules\tutorials\.env
```

Minimum required value:

```text
OPENAI_API_KEY=your_openai_key_here
```

Optional local/Ollama/Qdrant settings may look like this:

```text
OLLAMA_EMBED_MODEL=nomic-embed-text
OLLAMA_CHAT_MODEL=llama3.2
OLLAMA_CTX=8192
QDRANT_COLLECTION_NAME=time_molecules_directory
QDRANT_PATH=C:/MapRock/TimeMolecules/qdrant_data_ollama
```

Do not commit `.env` to GitHub.

For a reader VM, ship either:

```text
.env.example
```

or an `.env` with a placeholder key only.

---

## Step 11: Optional install of Ollama runtime

Ollama is optional for the OpenAI-only path, but useful for local model workflows.

There are two different Ollama pieces:

```text
Ollama runtime:
    Installed on Windows outside Python.

Python ollama package:
    Installed by pip from requirements.txt.
```

Install the Ollama runtime for Windows from the official Ollama download page. Ollama’s Windows page also shows the PowerShell install command. ([Ollama][5])

PowerShell install option:

```powershell
irm https://ollama.com/install.ps1 | iex
```

Pull local models:

```powershell
ollama pull nomic-embed-text
ollama pull llama3.2
```

Verify:

```powershell
ollama list
```

For a preconfigured reader VM, do this before capturing the image if you want local model support to work immediately.

---

## Step 12: Build the Qdrant vector index

The AI Agent Skills demo uses a vector index to retrieve Time Molecules tutorials, prompts, metadata, and related objects.

From the tutorials folder:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
```

Run the Qdrant build script used by the current refresh.

If the script is under `ai_agent_skills`:

```powershell
.\.venv\Scripts\python.exe ai_agent_skills\build_qdrant_index.py
```

If the script is directly under `tutorials`:

```powershell
.\.venv\Scripts\python.exe build_qdrant_index.py
```

If the current repo uses a differently named build script, search for it from PowerShell:

```powershell
dir *qdrant*.py -Recurse
dir *embedding*.py -Recurse
```

Then run the appropriate builder with:

```powershell
.\.venv\Scripts\python.exe path\to\the_builder.py
```

The intended Qdrant data path is typically:

```text
C:\MapRock\TimeMolecules\qdrant_data_ollama
```

The `.env` form is:

```text
QDRANT_PATH=C:/MapRock/TimeMolecules/qdrant_data_ollama
```

For a preconfigured reader VM, build Qdrant before capturing the image.

---

## Step 13: Run the AI Agent Skills demo

From the tutorials folder:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
.\.venv\Scripts\python.exe ai_agent_skills\time_molecules_agent_demo.py
```

The app should read configuration from `.env`, so no command-line arguments should be required.

---

# Visual Studio Code workflow

Open:

```text
C:\MapRock\TimeMolecules\tutorials
```

in VS Code.

Select the Python interpreter:

```text
Ctrl+Shift+P
→ Python: Select Interpreter
→ Enter interpreter path
```

Choose:

```text
C:\MapRock\TimeMolecules\tutorials\.venv\Scripts\python.exe
```

Open:

```text
C:\MapRock\TimeMolecules\tutorials\ai_agent_skills\time_molecules_agent_demo.py
```

Run:

```text
Right-click
→ Run Python File in Terminal
```

or:

```text
Run
→ Start Debugging
```

---

# Smoke tests

## SQL Server smoke test

In SSMS:

```sql
USE TimeSolution;
GO

SELECT DB_NAME() AS CurrentDatabase;
```

Optional object checks:

```sql
USE TimeSolution;
GO

SELECT OBJECT_ID('dbo.EventsFact') AS EventsFactObjectID;
SELECT OBJECT_ID('dbo.sp_SelectedEvents') AS SelectedEventsObjectID;
SELECT OBJECT_ID('dbo.ParseTransforms') AS ParseTransformsObjectID;
```

Expected: non-null object IDs for installed objects.

## Python smoke test

From PowerShell:

```powershell
cd C:\MapRock\TimeMolecules\tutorials

.\.venv\Scripts\python.exe --version
.\.venv\Scripts\python.exe -m pip --version
.\.venv\Scripts\python.exe -c "import openai; print('OpenAI import OK')"
```

If using Ollama:

```powershell
ollama list
.\.venv\Scripts\python.exe -c "import ollama; print('Ollama Python import OK')"
```

If using Qdrant:

```powershell
.\.venv\Scripts\python.exe -c "import qdrant_client; print('Qdrant client import OK')"
```

Run the app:

```powershell
.\.venv\Scripts\python.exe ai_agent_skills\time_molecules_agent_demo.py
```

---

# Preparing the VM for readers

Before capturing the VM image:

1. Remove your real OpenAI API key from:

   ```text
   C:\MapRock\TimeMolecules\tutorials\.env
   ```

2. Replace it with:

   ```text
   OPENAI_API_KEY=your_openai_key_here
   ```

3. Confirm SQL Server starts automatically.

4. Confirm `TimeSolution` is restored.

5. Confirm the Python venv exists:

   ```text
   C:\MapRock\TimeMolecules\tutorials\.venv
   ```

6. Confirm requirements are installed.

7. Confirm Qdrant is built if the image is supposed to include local vector search.

8. Confirm Ollama models are pulled if the image is supposed to include local model support.

9. Clear browser history, downloads, cache, cookies, saved passwords, and Outlook/OneDrive login state.

10. Check Windows Credential Manager for personal credentials.

11. Empty Recycle Bin.

12. Create desktop shortcuts:

    ```text
    Open Time Molecules README
    Configure OpenAI Key
    Run Time Molecules Agent Demo
    Open SSMS
    ```

13. Run a final smoke test using only a fresh OpenAI key.

---

# Common problems

## Cannot connect to SQL Server

Check that SQL Server is installed and the service is running.

Try server names:

```text
localhost
.
(local)
```

If using a named instance:

```text
localhost\InstanceName
```

## TimeSolution database is missing

Restore `TimeSolution.bak` in SSMS:

```text
Databases
→ Restore Database
→ Device
→ select TimeSolution.bak
```

## `.venv` not found

The expected path is:

```text
C:\MapRock\TimeMolecules\tutorials\.venv
```

Recreate it:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
py -3.12 -m venv .venv
```

## `Activate.ps1 is not recognized`

You are probably in the wrong folder.

Run:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
dir .venv\Scripts
```

Then:

```powershell
.\.venv\Scripts\Activate.ps1
```

## PowerShell blocks activation

Run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then:

```powershell
.\.venv\Scripts\Activate.ps1
```

## `.env` not found

Create:

```text
C:\MapRock\TimeMolecules\tutorials\.env
```

Minimum:

```text
OPENAI_API_KEY=your_openai_key_here
```

## Ollama not found

Install the Ollama runtime. The Python package alone is not enough. Ollama’s Windows download page provides the installer and PowerShell install command. ([Ollama][5])

Then:

```powershell
ollama pull nomic-embed-text
ollama pull llama3.2
ollama list
```

## Qdrant index missing or empty

From tutorials:

```powershell
cd C:\MapRock\TimeMolecules\tutorials
dir *qdrant*.py -Recurse
dir *embedding*.py -Recurse
```

Run the current Qdrant builder with the tutorial venv Python:

```powershell
.\.venv\Scripts\python.exe path\to\builder.py
```

## VS Code uses the wrong Python

Select:

```text
C:\MapRock\TimeMolecules\tutorials\.venv\Scripts\python.exe
```

through:

```text
Ctrl+Shift+P
→ Python: Select Interpreter
```

---

# Recommended final distribution pattern

For most readers:

```text
Use the preconfigured Time Molecules Demo VM.
Add your OpenAI API key.
Run the desktop shortcut.
```

For developers or people rebuilding the VM:

```text
Install SQL Server.
Install SSMS.
Restore TimeSolution.bak.
Install Git.
Clone the repo.
Install Python 3.12.
Install VS Code.
Create tutorials\.venv.
Install tutorials\requirements.txt.
Create tutorials\.env.
Install Ollama if using local models.
Build Qdrant.
Run the AI Agent Skills demo.
```

````

For the new VM test, use this as the exact build order:

```text
1. SQL Server
2. SSMS
3. Restore TimeSolution.bak
4. Git
5. Clone repo
6. Python 3.12
7. VS Code
8. tutorials\.venv
9. tutorials\requirements.txt
10. tutorials\.env
11. Ollama runtime and models, if included
12. Build Qdrant
13. Run app
14. Sanitize
15. Capture image
````

[1]: https://www.microsoft.com/en/sql-server/sql-server-downloads?utm_source=chatgpt.com "SQL Server Downloads"
[2]: https://learn.microsoft.com/en-us/ssms/?utm_source=chatgpt.com "SQL Server Management Studio"
[3]: https://learn.microsoft.com/en-us/ssms/install/install?utm_source=chatgpt.com "Install SQL Server Management Studio"
[4]: https://www.python.org/?utm_source=chatgpt.com "Welcome to Python.org"
[5]: https://ollama.com/download/windows?utm_source=chatgpt.com "Download Ollama on Windows"
