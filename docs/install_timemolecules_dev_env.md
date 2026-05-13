

# Time Solution Tutorial Environment

*Last Updated: June 4, 2025*

This document walks you through setting up the development environment required to follow along with the tutorials in the book *Time Molecules*. The environment includes SQL Server, Neo4j, Visual Studio Code, and Python. Follow the instructions step-by-step.

**Important:** If you didn't come here from [Setup Azure VM for Testing Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md), you might want to go there for instructions on building an Azuze Windows VM. This document is about installing the dev environment once you have your dev machine, whether Windows Azure VM or a desktop/laptop.

---

## Notes

* **TimeSolution SQL Server Database (`TimeSolution.bak`)**

  * The only material that isn’t directly observable (i.e., code and data you can directly read) is the SQL Server database backup file.
  * The file is around 50 MB and hosted on OneDrive (not GitHub due to size limits).
  * Download it only from the provided location. See [Download and Validate SQL Server Database](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.md#c-download-and-validate-timesolution-database)
  * The TimeSolution database contains the majority of the tutorial content.
  * Installing Python can be avoided if you just wish to run the [sql code from the book](https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql).
  * Neo4j is optional and can be skipped for a SQL-only setup and/or most of the Python tutorials.

---

## Prerequisites

This tutorial assumes you are working on a personal or work Windows 10/11 machine or a virtual machine (see [Setup Azure VM for Testing Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md)).

### Minimum Requirements

* **Local admin rights** (required to install):

  * SQL Server Developer Edition
  * SQL Server Management Studio - Run SQL queries and admin of the TimeSolution database.
  * Visual Studio Code - Run, edit, Python code - as well as viewing other documents such as CSV, Cypher code, markdowns, etc.
  * Python (3.10.2 or later)
  * Git for Windows (includes Git Bash)
  * Neo4j Desktop
  * OpenAI API key - A big theme of the Spring 2026 refresh is accomodating AI Agents consuming Time Molecules. Assuming you have an OpenAI account, go to https://platform.openai.com/api-keys to obtain the key. Be very careful not to let it leave your machine!
  * ollama - Optional local LLM alternative to a frontier LLM. Strongly recommend OpenAI over local LLM, since the Windows configuration is certainly serverely lacking (it'll be very slow).

* **Internet access**

  * Required for downloads, cloning GitHub, and accessing sample data

* **Machine specs**

  * At least 50 GB free
  * At least 4 CPU
  * At least 16 GB RAM

* **GitHub account**

  * Preferred, but it isn't necessary for cloning the [MapRock/TimeMolecules](https://github.com/MapRock/TimeMolecules) Github repo.
 
 ### Licensing Compliance Note

All software used in this tutorial is provided under licenses that are **explicitly legal for learning, development, and personal use**:

- **Windows Server 2025** (if using an Azure Windows VM) — The operating system license is **included** in the Azure VM hourly price.  
  When you reach the “Would you like to use an existing Windows Server license?” screen, simply **leave the box unchecked** unless you personally own a qualifying license with Software Assurance (Azure Hybrid Benefit). Most individual users following this tutorial leave it unchecked.

- **SQL Server 2025 Developer Edition** — Free for development, testing, evaluation, and learning purposes only. It may **not** be used in production.

- **Neo4j Desktop** — Free Developer license intended for internal development, evaluation, and learning only.

By following these instructions you remain fully compliant with Microsoft and Neo4j licensing terms. The tutorial environment is intentionally designed for **educational and development use only**.



### Alternative Arrangements

If you are a software developer, and you're using your own machine (not a VM), you may already have parts of the stack, such as the following:

#### Python

* Use PyCharm, Anaconda, or JupyterLab instead of VS Code. Python 3.12 and above.

#### SQL Server

* Use an existing instance (local or remote) - SQL Server 2022 or greater.
* Must have permission to restore databases

#### Neo4j (optional)
 
* Use existing Neo4j Desktop, Server, or Aura
* Must support plugins: APOC -- n10s is optional.

## Log onto Your Machine

The instructions from this point assume you are logged onto your Windows machine (real or virtual) with local admin rights.

A few general notes:

- While installing the various products, just click Next for defaults if I don't mention anything.
- There isn't anything that will require sign-in (except the Windows VM). That includes GitHub (we can clone the repo without logging in), OpenAI (except to obtain the API key). So just select the "skip login" (or whatever it may be).
- When you download something from a Web page (like SQL Server's install), it will download into the "Downloads" folder.

In your VM, open an instance of Microsoft Edge and navigate to:
https://github.com\maprock\timemolecules\docs\install_timemolecules_dev_env.md

That is this same page you're reading right now, but now you can readily copy/paste commands.


## Clone the Time Molecules Repository


### a. Create Local Folder

1. Open File Explorer.
2. Create a folder named C:/MapRock
3. Navigate to C:/MapRock
4. Click New Folder and name it TimeMolecules. You will have a folder named C:\MapRock\TimeMolecules, the base of operation.

### b. Install Git

1. Open an instance of Microsoft Edge. Just ignore all the prompts to log onto this or that, which will happen on a brand new VM.
2. Navigate to: [https://git-scm.com/download/win](https://git-scm.com/download/win)
3. Click "Git for Windows/x64 Setup" to download installer.
4. Excute the download and just click through the windows.

### c. Clone Repository

Open a Powershell window and run:

```bash
git clone https://github.com/MapRock/TimeMolecules.git C:/MapRock/TimeMolecules
```

There should be a folder c:/MapRock/TimeMolecules containing the Time Molecules GitHub material.


## SQL Server Setup

### a. Install SQL Server Developer Edition

Navigate to [https://www.microsoft.com/en-us/sql-server/sql-server-downloads](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)

Steps:

1. Download (Standard - not Enterprise) Developer Edition (choose SQL Server 2025 or 2022).
2. Run installer
3. Choose **Basic installation**
4. Accept license
5. Install
6. Note instance name (e.g., `MSSQLSERVER`)

---

### b. Install SSMS

Navigate to: [https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)

1. Click "Download SQL Server Management Studio 22 Installer".
2. Run installer - You do not need to check any boxes, just click "Install".

---

### c. Download and Validate TimeSolution Database

The TimeSolution SQL Server database (named TimeSolution.bak, developed with SQL Server 2022) is the core of the examples. It exists on a OneDrive location because of its size (a little more than 50 MB).

This file is the only file in the setup that isn't directly observable. So we will validate that it's the one I posted after you've downloaded it from the OneDrive location.

#### Download

* OneDrive link:
  [https://1drv.ms/u/c/7d94c9ab48b30303/EWpwyb0Z2-9AnOOBMK7ahXUBaskdgzsUUDLE_B3zvOuLeQ?e=LisfIo](https://1drv.ms/u/c/7d94c9ab48b30303/EWpwyb0Z2-9AnOOBMK7ahXUBaskdgzsUUDLE_B3zvOuLeQ?e=LisfIo)

**Move TimeSolution.bak** from the Downloads folder to c:/MapRock/TimeMolecules/data/

Note that these two files are in that folder as well:

* `publickeytm.asc`
* `timesolution.bak.asc`

---

#### Validate with GPG

Open GitBash, which should have been installed with Git.

```bash
cd /c/MapRock/TimeMolecules/data
gpg --import publickeytm.asc
gpg --verify timesolution.bak.asc timesolution.bak
```

Expected:

```
Good signature from "Eugene Asahara..."
```

Warning:

```
This key is not certified with a trusted signature
```

This is normal.

---

### d. Restore TimeSolution Database

Open SQL Server Management Studio. If you don't remember the Server Name, click Browse-> Local, and you'll see the server name (it should be the only entry).

Be sure to check "Trust Server Certificate".

1. Open SSMS
2. Right-click **Databases → Restore Database**
3. Select the "Device" option.
4. Click the three ellipses (...) on the right of the "Device" label.
5. Click "Add" and navigate to C:/MapRock/TimeMolecules/Data and select timesolution.bak
6. Click OK.

---

### d. Initialization Script

A small SQL script will "rehydrate" two tables that were truncated because of its size.

From SSMS, select File →Open →File, and navigate to C:/MapRock/TimeMolecules/book_code/sql/TimeMolecules_Code00.sql

It will open in a query window. Click Execute. It will take a couple of minutes.

This script does these things to the TimeSolution database:

1. Adds current SQL user to `dbo.Users`
2. Rebuilds:

  * `CasePropertiesParsed`
  * `EventPropertiesParsed`
3. Updates `dbo.Sources.ServerName`

These tables were truncated to reduce `.bak` size.

At this point, you have all you need to run the <i>[SQL code from the Time Molecules book](https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql)</i>.

Another good all-SQL demo is [Build Markov Model Process](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/build_markov_model_process.md), the <i>Time Molecules</i> version of kihon kata shodan(first basic karate kata).

---

### e. Security Model (Just FYI)

TimeSolution uses a bitmap-based access model.

#### Function

```sql
SELECT dbo.UserAccessBitmap()
```

#### Permissions

| Object               | Type     | Permission  | Notes                 |
| -------------------- | -------- | ----------- | --------------------- |
| dbo.UserAccessBitmap | Function | EXECUTE     | Required              |
| dbo.Users            | Table    | DENY SELECT | Enforced via function |

---

### f. Restore AdventureWorksDW2017 (Optional)

From the [official Microsoft open-source repo](https://github.com/microsoft), download the [.bak file for AdventureWorksDW2017](https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksDW2017.bak) within the [Microsoft SQL Server Samples repo](https://github.com/microsoft/sql-server-samples/releases/tag/adventureworks). 

Restore via SSMS the same way as with TimeSolution.bak.

---

## Neo4j Setup (Optional)

### a. Install

Navigate to: [https://neo4j.com/download/](https://neo4j.com/download/)

Project:

```
C:\MapRock\Neo4j
```

---

### b. Create Database

* Name: `TimeMolecules`
* Set password
* Start DB

---

### c. Install Plugins

* APOC
* n10s

---

### d. Import Directory

Example:

```
C:/Users/.../import/
```

Used for `.env` → `CYPHER_LOAD_DIR`

---

## Python & VS Code Setup

### a. Install Python

In Edge, Navigate to: [https://www.python.org/downloads/](https://www.python.org/downloads/)

Select "Download Python install manager" which should be under a label like "Download the latest version for Windows".

Open the downloaded installer, something like **python-manager-26.1.exe" in the Downloads folder.

After selecting Install, a couple of questions will appear. Answer Y to both of them. In particular **be certain to answer Y to the question: "Add commands directory to your PATH now?"**

### Create the Python virtual environment
The virtual environment belongs under the tutorials folder:

C:\MapRock\TimeMolecules\tutorials\.venv

From PowerShell, execute these commands one at a time.

```bash
cd C:\MapRock\TimeMolecules\py 
py -m venv .venv
```

Activate it:

```bash
.\.venv\Scripts\Activate.ps1
```

If activation is blocked:
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

```bash
.\.venv\Scripts\Activate.ps1
```
Activation is optional. You can always run Python directly:

```bash
.\.venv\Scripts\python.exe --version
```

Install Python requirements

The requirements file belongs here:

C:\MapRock\TimeMolecules\tutorials\requirements.txt
Install packages:

```bash
cd C:\MapRock\TimeMolecules\tutorials
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```
This installs the Python packages used by the tutorial app.

If requirements.txt includes the Python ollama package, that only installs the Python client. It does not install the Ollama Windows runtime.

---

### b. Install VS Code

Go to [https://code.visualstudio.com/](https://code.visualstudio.com/), and click **Download for Windows**.

---

### c. Install VS Code Extensions

| Area                 | Extension                        |                             Extension ID |                                    Version / pin recommendation | Why                                                                           |
| -------------------- | -------------------------------- | ---------------------------------------: | --------------------------------------------------------------: | ----------------------------------------------------------------------------- |
| SQL Server           | SQL Server / MSSQL               |                         `ms-mssql.mssql` |           **1.42.1** currently shown in Microsoft release notes | Run `.sql`, connect to SQL Server, browse objects, execute setup scripts      |
| Python               | Python                           |                       `ms-python.python` |                                                  Install latest | Main Python support; also pulls in Pylance, debugger, and environment tooling |
| Jupyter / notebooks  | Jupyter                          |                     `ms-toolsai.jupyter` |                                        Install latest, optional | Useful if you later add notebook-style experiments                            |
| Markdown             | Markdown All in One              |             `yzhang.markdown-all-in-one` |                                                  Install latest | Table of contents, Markdown editing, tutorial docs                            |
| GitHub-style preview | Markdown Preview GitHub Styling  | `bierner.markdown-preview-github-styles` |                                       **2.2.0** currently shown | Makes local Markdown preview closer to GitHub                                 |
| CSV                  | Rainbow CSV                      |                `mechatroner.rainbow-csv` |                                      **3.24.1** currently shown | Metadata CSVs, Qdrant export files, mapping files                             |

---



### e. Open Project

In Visual Code, select File -> Open Folder:

```
C:\MapRock\TimeMolecules\
```

---

### f. Setup `.env`

If you haven't yet obtained the OpenAI API key, now is the time. Nagivate to: https://platform.openai.com/api-keys

From Visual Studio, find the File Tutorials/.env.example and rename it to .env:

```
.env.example → .env
```

Edit:

```python
OPENAI_API_KEY="Your OpenAI API Key"
CYPHER_LOAD_DIR="Neo4j import path"
ADVENTUREWORKS_SERVER_NAME="Your SQL Server"
TIMESOLUTION_SERVER_NAME="Your SQL Server"
```

---


## Ollama Setup (Optional)

This is used as an alternative to a frontier model like OpenAI which requires a key, can incur token cost, and requires Internet connection.

### Install

Navigate to [https://ollama.com](https://ollama.com)

or:

```powershell
irm https://ollama.com/install.ps1 | iex
```

---

### Run Models

```bash
ollama run qwen3:14b
```

---

## Create Embeddings for TimeSolution objects and LLM Prompts

Embeddings are used by the workbench Python app, [Time Molecules Agent Demo](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/time_molecules_agent_demo.py)

These are the current setting of relevant parameters in the .env files:

```python
LLM="openai" # Lower case!! openai or ollama, grok.
EMBED_LLM="openai" # Lowerer case. openai or ollama.
OLLAMA_CHAT_MODEL=llama3.2
OLLAMA_EMBED_MODEL='nomic-embed-text'
OLLAMA_CTX=32768
# ChatGPT settings. Be sure to use CHATGPT_MODEL for normal LLM communication.
OPENAI_API_KEY="Your OpenAI API Key"
CHATGPT_MODEL="gpt-4.1" # 4754 max tokens for this model.
CHATGPT_EMBEDDING_MODEL="text-embedding-3-large"
```
These settings will build embeddings using OpenAI's embedding model (EMBED_LLM="openai"). That means it will consume tokens. There are about 650 Time Molecules objects and in the order of a few dozen article abstracts (LLM_Prompt) that will be consumed. It generally cost me a few cents of OpenAI tokens per run. 

There are two steps:

1. Build the embeddings vector database. This is a qdrant client, free of cost, a library of Python.
2. Run and experiment with the [Time Molecules Agent Demo](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/time_molecules_agent_demo.py) workbench app.

Both can be executed from Visual Studio (which should be open and ready to go) or through the Powershell CLI.

### Build the Embeddings

This will build an embedding database of Time Molecules objects.



Execute each line one by one:

```bash
cd C:\MapRock\TimeMolecules\tutorials
.\.venv\Scripts\python.exe ai_agent_skills\build_qdrant_index.py
```

### Test the Time Solution Client

Execute each line one by one:

```bash
cd C:\MapRock\TimeMolecules\tutorials
.\.venv\Scripts\python.exe ai_agent_skills\time_molecules_agent_demo.py
```
See [Time Molecules Agent Demo](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/time_molecules_agent_demo.md) for a discussion on how to use this.


## Stop the VM When Finished (Save Money!)

You are only charged while the VM is **Running**.

- Go back to the Azure Portal → select your VM → click **Stop**.
- Cost drops to **$0**.
- Start it again anytime — everything you saved is still there.

**Optional performance boost**: If you want even snappier responses, resize the VM to **Standard D8ds v4** (8 vCPU) in the Azure Portal. Still very affordable.



