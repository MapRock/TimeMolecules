
# Time Solution Tutorial Environment

By Eugene Asahara  
Last Updated: June 4, 2025

This document walks you through setting up the development environment required to follow along with the tutorials in the book, Time Molecules. The environment includes SQL Server, Neo4j, and , Visual Code, and Python. Follow the instructions step-by-step.

Notes:
• Timesolution SQL Server Database (timesolution.bak).
    ◦ The only material that isn’t directly observable (i.e. code and data you can directly read) is the SQL Server database backup file, TimeSolution.bak. 
    ◦ TimeSolution.bak is around 50 MB, too big for Github (especially when updating). The file is hosted on a Onedrive storage specified in this document. Be sure to download this file only from that location.
    ◦ The TimeSolution database comprises the vast majority of the tutorials in the book. The Neo4j and Python aspects of the tutorial are not required. This could simplify the installation to just SQL Server—which would be very convenient for those who are not software developers.

## Prerequisites

This tutorial assumes you are working on a personal or work laptop. Most of the setup will take place locally.

**Minimum Requirements**
• Local admin rights – Needed to install:
 o SQL Server Developer Edition
 o Neo4j Desktop
 o Python (3.10.2 or later)
 o Git for Windows (includes Git Bash)
• Internet access – Required for downloading installers, extensions, cloning the GitHub repo, and accessing the sample database files.
• Disk space – At least 10 GB free for SQL Server, database files, Neo4j, and Python packages.
• GitHub account– For cloning the Time Molecules GitHub repository and participating in any future updates.
    ◦ GitHub Desktop (optional) – A graphical interface for cloning and managing repositories.
    ◦ Git Bash (optional) – Used to validate the authenticity of the provided sample .bak file using GPG. Installed automatically with Git for Windows.

The primary tutorial is primarily within the SQL Server TimeSolution database. The samples and examples are run through SQL Server Management Studio (SSMS). Python, Neo4j, and Kyvos are optional if:

• These tutorials are skipped:
    ◦ Insight Space Graph Markov Models - Page 234: The Create_markov_data.py script assumes access to a Kyvos cube and uses the Kyvos Python SDK to query data.
    ◦ Custom Correlation Scores - page 241: This exercise assumes access to a Kyvos cube and uses the Kyvos Python SDK to query data.

## Alternative Arrangements 

If you're working on a restricted corporate laptop or already have parts of the stack available, you may not need to install everything:
• Python:
    ◦ If Python is already installed and you're using an IDE like PyCharm, Anaconda, or JupyterLab, you can use that instead of VS Code.
• SQL Server:
    ◦ If you already have access to a SQL Server instance (either local or remote), you can restore the TimeSolution.bak database there.
    ◦ Important: You must have permission to create or restore databases.
• Neo4j:
    ◦ If you’re already using Neo4j (Desktop, Server, or Aura), you may skip Neo4j Desktop installation.
    ◦ Important: You must be able to load plugins (e.g., APOC and n10s) and import data into the database.

This tutorial is modular—most of the core work happens in SQL Server. Python and Neo4j provide optional enhancements, analytics, and visualizations.

## Clone the Time Molecules Repository

Before setting up Python and VS Code, you’ll need to clone the Time Molecules GitHub repository to your local machine. This will give you access to all the scripts, notebooks, and configuration files used throughout the setup.

a. Create a Local Folder  
I recommend creating a base directory to hold the project: C:\MapRock\  
If this folder doesn’t exist, create it manually or let Git do it during the clone step.

b. Install Git (if not already installed)  
Download Git for Windows, which includes Git Bash:  
https://git-scm.com/download/win  
Follow the installation prompts. Leave most options at their defaults.

c. Clone the MapRock/TimeMolecules Repository  
Open Git Bash (or Command Prompt if Git is on your PATH), and run:  
```bash
git clone https://github.com/MapRock/TimeMolecules.git C:/MapRock/TimeMolecules
```  
This will download the full repository contents into C:\MapRock\TimeMolecules.

## SQL Server Setup

a. Install SQL Server Developer Edition (latest version)  
The Developer Edition of SQL Server provides the full feature set of the Enterprise Edition, but it's licensed for development and testing only.  

Steps:  
1. Open a browser and navigate to:  
https://www.microsoft.com/en-us/sql-server/sql-server-downloads  
2. Under "Developer edition", click the Download now button.  
3. When prompted, choose to run the installer or save it and run later.  
4. The SQL Server Installation Center will open. Choose Basic installation for quick setup.  
5. Accept the license terms, then click Install.  
6. Wait for the installation to complete. It will show you the instance name (default is SQLEXPRESS or MSSQLSERVER) and a summary.  
7. Note the SQL Server instance name, since you will use this when connecting via Management Studio or scripts.  
8. Optionally, you may want to open SQL Server Configuration Manager and ensure TCP/IP is enabled if remote access or ports are involved.

b. Install SQL Server Management Studio (SSMS)  
• Visit: https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms  
• Download and install the latest version of SSMS.

c. Download and Validate the Time Solution Database  
This step is optional, but recommended if you want to explore Time Molecules hands-on. The .bak file is a standard SQL Server backup file, which is not an executable and poses very little risk from a virus perspective. However, as with any downloaded file—especially one that restores a database—it’s wise to validate its authenticity.

That’s why I’ve included a digital signature you can verify using GPG. It’s a simple way to confirm the file hasn’t been tampered with and that it came from me. While a .bak file is unlikely to contain malicious code, databases can contain unexpected data, settings, or objects—so this extra step helps ensure integrity and trust.

- Download TimeSolution.bak from the provided OneDrive link:  
    - https://1drv.ms/u/c/7d94c9ab48b30303/EWpwyb0Z2-9AnOOBMK7ahXUBaskdgzsUUDLE_B3zvOuLeQ?e=LisfIo  
        - The kind of scary looking phrase, "There is no Preview ...", will display. It's a database backup, so that makes sense.
    - Three files are related to the SQL Server database:  
        - Timesolution.bak  
        - publickeytm.asc  
          - timesolution.bak.asc  
    ◦ Assuming a download of three files to:  
        ▪ C:\MapRock\TimeMolecules\data\  

• Validate with Git Bash.  
    ◦ Open Git Bash.  
    ◦ Navigate to data directory: cd /c/MapRock/TimeMolecules/data  
    ◦ Import public key: gpg --import publickeytm.asc  
    ◦ Run validation command: gpg --verify timesolution.bak.asc timesolution.bak  
        ▪ You Should see message: Good signature from "Eugene Asahara (For Time Molecules) <eugene@softcodedlogic.com>"  
        ▪   
        ▪ You may see the error: gpg: WARNING: This key is not certified with a trusted signature!   
            • This isn’t an error, just a trust model warning. It means GPG verified the signature cryptographically, but you haven’t explicitly trusted the key in your local keyring yet. GPG doesn’t know if you really trust that this public key belongs to Eugene Asahara—because no one has signed it in a "web of trust."

d. Restore the TimeSolution Database  
• Open SSMS and connect to your SQL Server instance.  
• Right-click on "Databases" > "Restore Database..."  
• Choose Device, click Add, and locate the TimeSolution.bak file.  
• Select the backup, ensure the restore paths are correct, and proceed.

d. Initialization Script  
Using SSMS, open and execute the TSQL script: c:\MapRock\TimeMolecules\book_code\sql\TimeMolecules_Code00.sql  
This is also a good way to ensure your SQL Server is set up. The script does three things:  
1. Adds you as a user to the dbo.Users table.  
2. Parses case and event properties—the CasePropertiesParsed and EventPropertiesParsed tables, respectively. I truncated them in order to significantly reduce the size of the TimeSolution.bak file. This part takes a few minutes.  
3. Sets the server name in the dbo.Sources table to the name of your SQL Server instance.  
You should see a result like this:

e. Securing Access to User Access Rights (Bitmap Access Model)  
The Time Solution database includes a security model that restricts direct access to the dbo.Users table. Each user’s access is defined by a bitmap, which encodes their permissions across rows in the dbo.Access table.  
Note: For the purposes of this tutorial, Part e is optional. The TimeSolution database should not be placed in production as it stands.  
To enforce access control while preserving query simplicity and performance, all permission lookups are exposed via a secure scalar function: dbo.UserAccessBitmap.  
Function-Based Access Pattern:  
• Function: dbo.UserAccessBitmap  
• Purpose: Returns the access bitmap for the current login, based on their row in dbo.Users.  
• Security Enforcement:  
The function encapsulates access to dbo.Users using SQL Server's ownership chaining model. This allows a user to execute the function without needing direct access to the underlying table.

Key Implementation Details:  
• dbo.UserAccessBitmap uses SUSER_NAME() (or optionally SUSER_SID()) to resolve the current user's identity and locate the corresponding access bitmap.  
• The function and dbo.Users must share the same schema owner (typically dbo) to ensure ownership chaining applies.  
• Direct access to the dbo.Users table should be revoked or denied for all non-administrative users.  

**Permissions Setup**

| Object                | Type        | Permission            | Notes                                              |
|-----------------------|-------------|-----------------------|----------------------------------------------------|
| dbo.UserAccessBitmap  | Scalar Func | GRANT EXECUTE         | Grant to users or roles that need access evaluation |
| dbo.Users             | Table       | DENY SELECT or REVOKE | Prevents direct access; enforced via function layer |

Applications or queries needing to evaluate access should use this function:  
```sql
SELECT dbo.UserAccessBitmap() AS UserAccessMask;
```  
This will return a BIGINT bitmap that maps to access entries in the dbo.Access table (e.g., bit 1 = row 1, bit 2 = row 2, etc.).

f. Restore AdventureWorksDW2017 (optional)  
1. Go to the official Microsoft GitHub repository for sample databases:  
https://github.com/microsoft/sql-server-samples/releases/tag/adventureworks  
1. Scroll down to the Assets section under "AdventureWorks 2017 OLAP".  
2. Download the file: AdventureWorksDW2017.bak  

2. Restore the Database in SSMS  
1. Open SQL Server Management Studio (SSMS).  
2. Connect to your SQL Server instance.  
3. Right-click on Databases → choose Restore Database...  
4. Select Device → Click the "..." → Add  
→ Locate and select AdventureWorksDW2017.bak.  
5. In the Files tab, verify the restore paths (or change to a writable directory).  
6. Click OK to restore.

## Neo4j Setup

a. Install Neo4j Desktop  
• Visit: https://neo4j.com/download/  
• Download and install Neo4j Desktop.  
• When prompted, sign in or create a free Neo4j account to activate the software.  
• After launching, Neo4j Desktop will prompt you to create a new project.  
 ○ Name the project something like TimeMoleculesProject.  
 ○ Set the base project folder to: C:\MapRock\Neo4j  

b. Create the TimeMolecules Database  
1. Within the project, click "Add" → "Local DBMS".  
2. In the dialog:  
    ◦ Set Name to: TimeMolecules  
    ◦ Set Password: Choose a password you’ll remember (e.g., neo4j). You’ll need this when Python or Neo4j Browser connects.  
    ◦ Leave default version and settings unless you need specific configuration.  
3. Click "Create" to finish setting up the database.  
4. After it’s created, click "Start" to launch the TimeMolecules database.

c. Configure Neo4j Plugins  
1. Once the database is running, click on the TimeMolecules DB.  
2. Select the "Plugins" tab.  
3. Install the following:  
    ◦ APOC: Utility procedures for common operations.  
    ◦ n10s (Neosemantics): Enables working with RDF/OWL and linked data.

d. Locate the Import Directory  
You'll need this directory for loading CSV files into Neo4j:  
1. In Neo4j Desktop, go to your running TimeMolecules database.  
2. Click the three dots (•••) next to the database name.  
3. Select "Open Folder"  
4. Navigate to the import subfolder.  
5. This path will be used in your .env file for CYPHER_LOAD_DIR.

Example path:  
C:/Users/yourname/Neo4j/relate-data/dbmss/dbms-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/import/  
This folder is where you’ll copy any .csv files you want Neo4j to load. This will be used in the .env file as explained in part f of the “Python and VS Code Setup” topic.

## Python and VS Code Setup

a. Install Python (version 3.10.2 or later)  
• Visit: https://www.python.org/downloads/  
• Download and install version 3.10.2 or later.  
• Add Python to PATH during installation.

b. Install Visual Studio Code (VS Code)  
• Visit: https://code.visualstudio.com/  
• Download and install VS Code.

c. Add VS Code Extensions  
• Launch VS Code.  
• Click the Extensions icon in the Activity Bar on the side (or press Ctrl+Shift+X).  
• In the Extensions pane, type the following names one by one into the search bar:  
    ◦ Jupyter by Microsoft: Enables support for Jupyter notebooks (.ipynb files).  
    ◦ Neo4j for VS Code by neo4j.com: Provides database integration, query execution, and exploration for Neo4j.  
    ◦ Cypher Query Language: Adds syntax highlighting for Cypher if not already covered by the Neo4j extension.  
• Click Install on each relevant result.  
• Reload VS Code when prompted after installation.

d. Clone the GitHub Repository  
• Run: git clone https://github.com/MapRock/TimeMolecules.git C:\MapRock\TimeMolecules  
• If you’ve already cloned the main branch, you can use this command to refresh your local directory: git pull origin main

e. Open Project in VS Code  
• Launch Visual Studio Code.  
• From the File menu, select Open Folder…  
• Navigate to:  
 C:\MapRock\TimeMolecules\book_code\src  
 and click Select Folder.  
• This folder contains all the Python scripts and configuration files needed to run the Time Molecules examples.  
• If prompted to install Python or related extensions, accept the suggestions.  
• Make sure the Explorer pane (left sidebar) is open so you can see the file structure.  
• You’ll be editing files like .env, *.ipynb notebooks, and Python modules here.

f. Set Up the Environment Variables  
This step configures essential settings required by the Time Molecules Python code to connect to external services like OpenAI, your local Neo4j instance, and SQL Server databases. These settings are stored in a special file named .env, short for "environment." The .env file is not part of the code itself but is automatically loaded at runtime to provide secure and customizable configuration values—such as API keys and file paths—without hardcoding them. By renaming the provided .env.example and editing its contents, you create a personal configuration file tailored to your system.  
• In the src folder of the cloned repository, locate the file named .env.example.  
    ◦ Rename the file to .env  
• Select the .env file in the src folder and set the following contents:  
    ◦ OPENAI_API_KEY="Your OpenAI API Key"  
    ◦ CYPHER_LOAD_DIR="C:/Databases/Neo4j/relate-data/dbmss/dbms-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/import/"  
    ◦ ADVENTUREWORKS_SERVER_NAME="Your Desktop SQL Server Name"  
    ◦ TIMESOLUTION_SERVER_NAME="Your Desktop SQL Server Name"

With this environment, you're ready to run the Time Solution components across SQL Server, Neo4j, and Python.

## Kyvos Setup

⚠️ This is optional. You will need a valid Kyvos account, appropriate role permissions, and network access to your Kyvos cluster. Work with your IT team or Kyvos representative to ensure connectivity.  
This script assumes access to a Kyvos cube and uses the Kyvos Python SDK to query data. Kyvos is required for create_Markov_data.py. However, in order to work around this requirement, the end product of this script, a csv file named sales_event_data.csv, is included in the supplemental material:

c:\MapRock\TimeMolecules\demo_output\sales_event_data.csv

a. Obtain Access to a Kyvos Environment  
• Kyvos is a commercial OLAP platform. To use it, your organization must have an active Kyvos cluster.  
• If your organization does not already have access:  
 o Visit: https://www.kyvosinsights.com  
 o Contact Kyvos sales or support to initiate a license agreement and cluster provisioning.

b. Install the Kyvos ODBC Driver  
• Once access is granted, log in to the Kyvos web portal.  
• Navigate to the Downloads section to obtain the appropriate ODBC driver for your operating system.  
• Install the driver on your local machine.  
• During installation, follow all prompts and ensure the driver is registered with the ODBC Data Source Administrator.

c. Configure the Kyvos DSN (Data Source Name)  
Open the ODBC Data Source Administrator:  
 • On Windows, search for ODBC in the Start Menu and choose “ODBC Data Sources (64-bit)”.  
Navigate to the System DSN tab and click Add.  
Select the Kyvos ODBC Driver from the list and click Finish.  
Enter the required connection details:  
 • DSN Name: Choose a meaningful name (e.g., Kyvos_TimeMolecules)  
 • Server/Host: Your Kyvos Query Engine IP or hostname  
 • Port: Typically 8080 or as provided by your administrator  
 • Username/Password: Your Kyvos credentials  
 • Catalog/Cube: As directed by your Kyvos admin for testing or Time Molecules integration  
Test the connection and click OK to save the DSN.

With the DSN set up, you can connect to Kyvos cubes using Python, SQL Server Linked Servers, or BI tools that support ODBC (e.g., Excel, Power BI, Tableau).

## Ollama Setup (Optional but Recommended for AI Features)

This section adds local Artificial Intelligence capabilities to your Time Molecules development environment. Ollama allows you to run powerful large language models entirely on your laptop for tasks such as brainstorming ideas, explaining complex concepts from the book, generating code snippets, assisting with writing, and creating embeddings for semantic search over your notes, tutorial content, or documents.

**Important:** Everything runs 100% locally on your machine. No prompts or data are sent over the internet after the initial model download. This provides full privacy with no subscription costs or usage limits.

### 1. Install Ollama
1. Go to the official Ollama website: https://ollama.com  
2. Download the Windows installer and run it.  
3. Alternatively, install via PowerShell (run as Administrator):

```powershell
irm https://ollama.com/install.ps1 | iex
```

4. After installation, launch the Ollama application from the Windows Start Menu. It may appear as a small llama icon in the system tray.

### 2. Pull a Strong Chat Model
Open Command Prompt or PowerShell and run one of the following commands:

```bash
# Recommended starting model – good balance of intelligence and speed on most laptops
ollama run qwen3:14b
```

Alternative models you can try:  
- `ollama run qwen3:32b` – Stronger reasoning (requires more RAM, preferably 32 GB or higher)  
- `ollama run llama3.3:8b` – Natural conversation style  
- `ollama run deepseek-r1:14b` – Excellent for step-by-step reasoning and analysis  

The first time you run a model, Ollama will automatically download it. This may take 10–40 minutes depending on your internet speed and the model size.

### 3. Pull an Embedding Model (for Semantic Search / RAG)
Ollama also supports embeddings, which are useful for building a local knowledge base or searching your own writing, notes, and tutorial excerpts semantically.

Run the following command:

```bash
ollama pull nomic-embed-text
```

Alternative embedding models:  
- `ollama pull mxbai-embed-large` (higher quality)  
- `ollama pull qwen3-embedding:0.6b` (lightweight and fast)

### 4. Python Example – Using Embeddings with Ollama

Create a new Python file in your `book_code\src` folder (for example: `ollama_embeddings_demo.py`) with the following code:

```python
import ollama
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# Configuration
EMBED_MODEL = "nomic-embed-text"

def get_embedding(text: str):
    """Generate embedding for a single piece of text"""
    response = ollama.embeddings(model=EMBED_MODEL, prompt=text)
    return response['embedding']

# Example documents – replace or expand with your own notes or tutorial excerpts
documents = [
    "The TimeSolution database uses a bitmap-based access control model via the dbo.UserAccessBitmap function.",
    "Neo4j with APOC and n10s plugins is used for modeling Insight Space Graph Markov Models.",
    "The initialization script parses case and event properties from raw data.",
    "Running large language models locally with Ollama provides complete privacy with no subscription costs."
]

def semantic_search(query: str, docs: list, top_k: int = 3):
    """Perform semantic search on documents using embeddings"""
    print(f"🔍 Searching for: '{query}'\n")
    
    query_embedding = get_embedding(query)
    doc_embeddings = [get_embedding(doc) for doc in docs]
    
    similarities = cosine_similarity([query_embedding], doc_embeddings)[0]
    top_indices = np.argsort(similarities)[::-1][:top_k]
    
    for rank, idx in enumerate(top_indices, 1):
        print(f"{rank}. Score: {similarities[idx]:.4f}")
        print(f"   {docs[idx]}\n")

# Run the demo
if __name__ == "__main__":
    semantic_search("How does the bitmap access model work in the TimeSolution database?", documents)
```

**Required Python packages (install once):**

```bash
pip install ollama numpy scikit-learn
```

