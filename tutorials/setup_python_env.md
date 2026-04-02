# Python Environment Setup for `tutorials`

These instructions are for someone who downloaded or cloned the `TimeMolecules` repo and wants to run the Python examples under `tutorials`.

## Prerequisites

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
