

# Time Solution Tutorial Environment

*Last Updated: June 4, 2025*

This document walks you through setting up the development environment required to follow along with the tutorials in the book *Time Molecules*. The environment includes SQL Server, Neo4j, Visual Studio Code, and Python. Follow the instructions step-by-step.

**Important:** If you didn't come here from [Setup Azure VM for Testing Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md), you might want to go there for instructions on building an Azuze Windows VM. This document is about installing the dev environment once you have the VM.

---

## Notes

* **TimeSolution SQL Server Database (`TimeSolution.bak`)**

  * The only material that isn’t directly observable (i.e., code and data you can directly read) is the SQL Server database backup file.
  * The file is around 50 MB and hosted on OneDrive (not GitHub due to size limits).
  * Download it only from the provided location. See [Download and Validate SQL Server Database](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.md#c-download-and-validate-timesolution-database)
  * The TimeSolution database contains the majority of the tutorial content.
  * Installing Python can be avoided if you just wish to run the [sql code from the book](https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql).
  * Neo4j is optional and can be skipped for a SQL-only setup.

---

## Prerequisites

This tutorial assumes you are working on a personal or work Windows 10/11 machine or a virtual machine (see [Setup Azure VM for Testing Time Molecules](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_azure_vm_for_testing_time_molecules.md)).

### Minimum Requirements

* **Local admin rights** (required to install):

  * SQL Server Developer Edition
  * Neo4j Desktop
  * Python (3.10.2 or later)
  * Git for Windows (includes Git Bash)

* **Internet access**

  * Required for downloads, cloning GitHub, and accessing sample data

* **Machine specs**

  * At least 50 GB free
  * At least 4 CPU
  * At least 16 GB RAM

* **GitHub account**

  * Preferred, but not necessary for cloning the [MapRock/TimeMolecules](https://github.com/MapRock/TimeMolecules) github repo.


## Alternative Arrangements

If you are a software developer, you may already have parts of the stack:

### Python

* Use PyCharm, Anaconda, or JupyterLab instead of VS Code. Python 3.12 and above.

### SQL Server

* Use an existing instance (local or remote) - SQL Server 2022 or greater.
* Must have permission to restore databases

### Neo4j

* Use existing Neo4j Desktop, Server, or Aura
* Must support plugins: APOC -- n10s is optional.

---



## Clone the Time Molecules Repository

### a. Create Local Folder

```
In File Explorer, create the new folder: C:\MapRock\
```

### b. Install Git

[https://git-scm.com/download/win](https://git-scm.com/download/win)

Just click through.

### c. Clone Repository

Open a Powershell window and run:

```bash
git clone https://github.com/MapRock/TimeMolecules.git C:/MapRock/TimeMolecules
```
There should be a folder c:/MapRock/TimeMolecules containing the Time Molecules GitHub material.
---

## SQL Server Setup

### a. Install SQL Server Developer Edition

[https://www.microsoft.com/en-us/sql-server/sql-server-downloads](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)

Steps:

1. Download (Standard - not Enterprise) Developer Edition (choose SQL Server 2025 or 2022).
2. Run installer
3. Choose **Basic installation**
4. Accept license
5. Install
6. Note instance name (e.g., `MSSQLSERVER`)

---

### b. Install SSMS

[https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)

---

### c. Download and Validate TimeSolution Database

The TimeSolution SQL Server database (named TimeSolution.bak, developed with SQL Server 2022) is the core of the examples. It exists on a OneDrive location because of its size (a little more than 50 MB).

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

### d. Restore Database

Open SQL Server Management Studio. If you don't remember the Server Name, click Browse-> Local.

Be sure to check "Trust Server Certificate".

1. Open SSMS
2. Right-click **Databases → Restore Database**
3. Select the "Device" option.
4. Click the ... on the right of the "Device" label.
5. Click "Add" and navigate to C:/MapRock/TimeMolecules/Data and select timesolution.bak
6. Click OK.

---

### d. Initialization Script

A small SQL script will "rehydrate" two tables that were truncated because of its size.

From SSMS, select File->Open->File, and navigate to C:/MapRock/TimeMolecules/book_code/sql/TimeMolecules_Code00.sql

From SSMS, navigate to Files/Open, and open: C:/MapRock/TimeMolecules/book_code/sql/TimeMolecules_Code00.sql

It will open in a query window. Click Execute. It will take a couple of minutes.

This script:

* Adds current SQL user to `dbo.Users`
* Rebuilds:

  * `CasePropertiesParsed`
  * `EventPropertiesParsed`
* Updates `dbo.Sources.ServerName`

These tables were truncated to reduce `.bak` size.

---

### e. Security Model (Optional)

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

Download:
[https://github.com/microsoft/sql-server-samples/releases/tag/adventureworks](https://github.com/microsoft/sql-server-samples/releases/tag/adventureworks)

Restore via SSMS.

---

## Neo4j Setup (Optional)

### a. Install

[https://neo4j.com/download/](https://neo4j.com/download/)

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

[https://www.python.org/downloads/](https://www.python.org/downloads/)

Select "Download Python install manager" which should be under a label like "Download the latest version for Windows".

Open the downloaded exe, something like **python-manager-26.1.exe" in the Downloads folder.

After selecting Install, a couple of questions will appear. Answer Y to both of them, **especially** "Add commands directory to your PATH now?"

### Create the Python virtual environment
The virtual environment belongs under the tutorials folder:

C:\MapRock\TimeMolecules\tutorials\.venv
From PowerShell:

```bash
cd C:\MapRock\TimeMolecules\tutorials
py -3.12 -m venv .venv
```

Activate it:

```bash
.\.venv\Scripts\Activate.ps1
If activation is blocked:
```

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

```bash
.\.venv\Scripts\Activate.ps1
```
Activation is optional. You can always run Python directly:

```bash
.\.venv\Scripts\python.exe --version
```

Step 9: Install Python requirements
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

[https://code.visualstudio.com/](https://code.visualstudio.com/)

---

### c. Install Extensions

* Jupyter
* Neo4j
* Cypher

---



### e. Open Project

In Visual Code, select File -> Open Folder:

```
C:\MapRock\TimeMolecules\
```

---

### f. Setup `.env`

Rename:

```
.env.example → .env
```

Edit:

```env
OPENAI_API_KEY="Your OpenAI API Key"
CYPHER_LOAD_DIR="Neo4j import path"
ADVENTUREWORKS_SERVER_NAME="Your SQL Server"
TIMESOLUTION_SERVER_NAME="Your SQL Server"
```

---

## Kyvos Setup (Optional)

Requires enterprise access.

* [https://www.kyvosinsights.com](https://www.kyvosinsights.com)

Steps:

1. Install ODBC driver
2. Configure DSN
3. Connect via Python or BI tools

---

## Ollama Setup (Optional)

### Install

[https://ollama.com](https://ollama.com)

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

### Embeddings

```bash
ollama pull nomic-embed-text
```

---

### Python Example

```python
import ollama
```

Install:

```bash
pip install ollama numpy scikit-learn
```

