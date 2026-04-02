# Python Environment Setup for `tutorials`

These instructions are for someone who downloaded or cloned the `TimeMolecules` repo and wants to run the Python examples under `tutorials`.

## Important Notes
### Security Notice About `.env`

The `.env` file is **for local use only** and must **never** be committed, uploaded, or published to GitHub or any other source control system.

A `.env` file commonly contains private or sensitive information such as:

- API keys
- passwords
- database connection details
- server names
- local paths
- other environment-specific settings

If you upload `.env`, you may expose credentials or private infrastructure details to other people. Even if you delete the file later, the information may still remain in Git history, forks, caches, logs, or other copies outside this repository.

By using these tutorials, you acknowledge that:

1. You are solely responsible for protecting your own credentials, keys, passwords, and configuration values.
2. You must keep your real `.env` file only on your local machine.
3. You must add `.env` to your `.gitignore` before committing changes.
4. If you accidentally expose secrets, you are responsible for rotating or revoking them immediately.
5. The author and contributors are not responsible for any loss, exposure, misuse, charges, or damages resulting from your decision to store, commit, upload, share, or fail to protect your own secrets or environment files.

At a minimum, your `.gitignore` should include:

```gitignore
.env
.env.*
````

A safer pattern is to commit a template file such as `.env.example` with placeholder values, and keep your real `.env` private on your own machine.

Example:

```env
OPENAI_API_KEY=your_key_here
TIMESOLUTION_DATABASE_NAME=TimeSolution
```

Then create your own local `.env` from that template and fill in your real values privately.

#### If you accidentally upload `.env`

Treat that as a credential leak.

Immediately:

1. delete the file from the repository
2. add `.env` to `.gitignore`
3. rotate or revoke any exposed API keys, passwords, or tokens
4. consider cleaning the file from Git history if it was committed

Do not assume that deleting the file later makes the secret safe again.


### Prerequisites

- Python 3.10 or later recommended
- `pip`
- Git optional, if you are cloning instead of downloading
- For scripts that connect to SQL Server, an appropriate SQL Server ODBC driver must also be installed on the machine
- An OpenAI API key if the script uses the OpenAI API

The current OpenAI Python package supports Python 3.9 and later. The basic install command is `pip install openai`. The package documentation also recommends using `python-dotenv` with an `.env` file for `OPENAI_API_KEY`. :contentReference[oaicite:0]{index=0}

## 1. Get the code

Either clone the repo:

```bash
git clone https://github.com/MapRock/TimeMolecules.git
cd TimeMolecules
````

Or download the ZIP from GitHub and extract it, then open a terminal in the extracted `TimeMolecules` folder.

## 2. Create a virtual environment

From the root of the repo:

### Windows

```bash
py -3.10 -m venv .venv
.venv\Scripts\activate
```

### macOS / Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
```

After activation, your prompt should show something like `(.venv)`.

## 3. Upgrade packaging tools

```bash
python -m pip install --upgrade pip setuptools wheel
```

## 4. Install Python packages

If the repo includes a `requirements.txt`, install from that:

```bash
python -m pip install -r requirements.txt
```

If you are only setting up the currently discussed tutorial scripts, this set is enough:

```bash
python -m pip install python-dotenv pyodbc pandas requests openai
```

`openai`, `python-dotenv`, `pyodbc`, `pandas`, and `requests` are all distributed on PyPI. ([PyPI][1])

## 5. Create the `.env` file

Create a file named `.env` in the repo root, for example:

```env
OPENAI_API_KEY=your_openai_api_key_here
TIMESOLUTION_DATABASE_NAME=TimeSolution
```

You can add other local settings there as needed.

Do **not** commit `.env` to source control.

## 6. Make sure Python can find `.env`

If a script is in a subdirectory under `tutorials`, a robust pattern is to search upward from the script location until `.env` is found.

Example:

```python
from pathlib import Path
from dotenv import load_dotenv

current = Path(__file__).resolve()
env_path = None

for parent in [current.parent, *current.parents]:
    candidate = parent / ".env"
    if candidate.exists():
        env_path = candidate
        break

if env_path is None:
    raise FileNotFoundError(".env not found in this directory or any parent directory")

load_dotenv(env_path)
```

This works whether `.env` is:

* in the same directory as the script, or
* higher up, such as in the repo root

## 7. Run a tutorial script

Example:

```bash
python tutorials/link_cases/source_column_semantic_similarity.py
```

Or, if you first change directories:

```bash
cd tutorials/link_cases
python source_column_semantic_similarity.py
```

## 8. Common problems

### Wrong Python / wrong pip

Always prefer:

```bash
python -m pip install ...
```

instead of plain:

```bash
pip install ...
```

This helps ensure packages are installed into the same interpreter you are using to run the script.

To verify:

```bash
python --version
python -m pip --version
python -m pip show openai
```

### ODBC connection errors

If the script uses `pyodbc` to connect to SQL Server, make sure a suitable Microsoft SQL Server ODBC driver is installed on the machine.

### `.env` not found

Make sure the file is actually named `.env`, not `.env.txt`, and that it is placed either:

* beside the script, or
* somewhere above it in the directory tree

### Missing API key

If the script uses OpenAI and `OPENAI_API_KEY` is missing, the client will not authenticate.

## 9. Deactivate the environment

When you are done:

```bash
deactivate
```

## 10. Re-enter later

From the repo root:

### Windows

```bash
.venv\Scripts\activate
```

### macOS / Linux

```bash
source .venv/bin/activate
```


[1]: https://pypi.org/project/openai/ "openai · PyPI"
