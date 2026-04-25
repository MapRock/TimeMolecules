

# Time Solution Tutorial Environment

**By Eugene Asahara**
*Last Updated: June 4, 2025*

This document walks you through setting up the development environment required to follow along with the tutorials in the book *Time Molecules*. The environment includes SQL Server, Neo4j, Visual Studio Code, and Python. Follow the instructions step-by-step.

---

## Notes

* **TimeSolution SQL Server Database (`TimeSolution.bak`)**

  * The only material that isn’t directly observable (i.e., code and data you can directly read) is the SQL Server database backup file.
  * The file is around 50 MB and hosted on OneDrive (not GitHub due to size limits).
  * Download it only from the provided location.
  * The TimeSolution database contains the majority of the tutorial content.
  * Neo4j and Python are optional and can be skipped for a SQL-only setup.

---

## Prerequisites

This tutorial assumes you are working on a personal or work laptop. Most setup occurs locally.

### Minimum Requirements

* **Local admin rights** (required to install):

  * SQL Server Developer Edition
  * Neo4j Desktop
  * Python (3.10.2 or later)
  * Git for Windows (includes Git Bash)

* **Internet access**

  * Required for downloads, cloning GitHub, and accessing sample data

* **Disk space**

  * At least 10 GB free

* **GitHub account**

  * Needed to clone the repository

Optional tools:

* GitHub Desktop (GUI for Git)
* Git Bash (used for GPG validation)

---

## Optional Components

The primary work happens in SQL Server.

You may skip Python/Neo4j if you skip:

* **Insight Space Graph Markov Models (p.234)**
* **Custom Correlation Scores (p.241)**

These require Kyvos.

---

## Alternative Arrangements

You may already have parts of the stack:

### Python

* Use PyCharm, Anaconda, or JupyterLab instead of VS Code

### SQL Server

* Use an existing instance (local or remote)
* Must have permission to restore databases

### Neo4j

* Use existing Neo4j Desktop, Server, or Aura
* Must support plugins (APOC, n10s)

---

## Clone the Time Molecules Repository

### a. Create Local Folder

```
C:\MapRock\
```

### b. Install Git

[https://git-scm.com/download/win](https://git-scm.com/download/win)

### c. Clone Repository

```bash
git clone https://github.com/MapRock/TimeMolecules.git C:/MapRock/TimeMolecules
```

---

## SQL Server Setup

### a. Install SQL Server Developer Edition

[https://www.microsoft.com/en-us/sql-server/sql-server-downloads](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)

Steps:

1. Download Developer Edition
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

#### Download

* OneDrive link:
  [https://1drv.ms/u/c/7d94c9ab48b30303/EWpwyb0Z2-9AnOOBMK7ahXUBaskdgzsUUDLE_B3zvOuLeQ?e=LisfIo](https://1drv.ms/u/c/7d94c9ab48b30303/EWpwyb0Z2-9AnOOBMK7ahXUBaskdgzsUUDLE_B3zvOuLeQ?e=LisfIo)

Files:

* `TimeSolution.bak`
* `publickeytm.asc`
* `timesolution.bak.asc`

Save to:

```
C:\MapRock\TimeMolecules\data\
```

---

#### Validate with GPG

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

1. Open SSMS
2. Right-click **Databases → Restore Database**
3. Select `.bak` file
4. Restore

---

### d. Initialization Script

Run:

👉 [https://github.com/MapRock/TimeMolecules/blob/main/book_code/sql/TimeMolecules_Code00.sql](https://github.com/MapRock/TimeMolecules/blob/main/book_code/sql/TimeMolecules_Code00.sql)

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

## Neo4j Setup

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

---

### b. Install VS Code

[https://code.visualstudio.com/](https://code.visualstudio.com/)

---

### c. Install Extensions

* Jupyter
* Neo4j
* Cypher

---

### d. Clone Repo (if needed)

```bash
git clone https://github.com/MapRock/TimeMolecules.git C:\MapRock\TimeMolecules
git pull origin main
```

---

### e. Open Project

Open:

```
C:\MapRock\TimeMolecules\book_code\src
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

