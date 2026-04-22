

# Windows Setup for the Python Tutorials

These steps explain how to get the Python-based tutorials running on Windows, starting from scratch.

They assume:

* you already downloaded or cloned the `TimeMolecules` repository
* you want to work from the `tutorials` folder
* you may **not** already have Python installed

---

## Before you start

Some of the tutorials use Python.

If Python is **not** already installed on your machine, install **Python 3.10 or later** first.

### How to install Python

1. Go to **python.org**
2. Download **Python 3.10 or later** for Windows
3. Run the installer

During installation, if you see an option like:

```text
Add Python to PATH
```

check it if you want. But if you do not, that is okay. These instructions will still work.

If you have the choice, installing Python to a simple location such as:

```text
C:\python310
```

is fine.

---

# Step 1: Open the correct folder

After downloading or cloning the repository, open **File Explorer** and go to the `tutorials` folder.

For example:

```text
C:\maprock\timemolecules\tutorials
```

This `tutorials` folder is the base for the Python environment.

---

# Step 2: Open PowerShell in that folder

While you are in the `tutorials` folder in File Explorer:

1. Click in the **address bar**
2. Type:

```text
powershell
```

3. Press **Enter**

This opens a PowerShell window already pointed at the correct folder.

You will type the commands below into that PowerShell window.

---

# Step 3: Create the virtual environment

If Python is installed at `C:\python310`, run:

```powershell
C:\python310\python.exe -m venv .venv
```

This creates a local Python environment named `.venv` inside the `tutorials` folder.

You only need to do this once.

## If Python was installed somewhere else

Use that full path instead. For example:

```powershell
C:\Path\To\Python\python.exe -m venv .venv
```

## If you are not sure where Python is installed

Try one of these commands:

```powershell
py --version
```

or

```powershell
python --version
```

If one of those works, you can try:

```powershell
py -m venv .venv
```

or

```powershell
python -m venv .venv
```

If neither works, then Python is either not installed or not easy to find on that machine. In that case, install Python first and then come back to this step.

---

# Step 4: Activate the virtual environment

Still in the `tutorials` folder, run:

```powershell
.\.venv\Scripts\Activate.ps1
```

If it works, you should usually see something like this at the start of the prompt:

```text
(.venv)
```

That means the virtual environment is active.

---

# Step 5: If PowerShell blocks activation

Some Windows machines block PowerShell scripts the first time.

If you get an error saying that script execution is disabled, run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

When PowerShell asks for confirmation, type:

```text
Y
```

Then activate the environment again:

```powershell
.\.venv\Scripts\Activate.ps1
```

You usually only need to do the execution-policy step once.

---

# Step 6: Upgrade pip

After the virtual environment is active, run:

```powershell
python -m pip install --upgrade pip
```

---

# Step 7: Install the Python requirements

From the `tutorials` folder, install the requirements for the tutorial you want to run.

For example, for the AI agent tutorial:

```powershell
pip install -r ai_agent_skills\requirements.txt
```

If you are already inside `tutorials\ai_agent_skills`, use:

```powershell
pip install -r requirements.txt
```

---

# Step 8: Test that the environment is working

You can test Python itself with:

```powershell
python --version
```

If you have a small checker script such as `test_requirements.py`, you can run:

```powershell
python test_requirements.py
```

That is a quick way to see whether the required packages are importable.

---

# Step 9: Each time you come back later

You do **not** need to recreate the virtual environment every time.

When you come back later:

1. Open File Explorer
2. Go to the `tutorials` folder
3. Type `powershell` in the address bar
4. Press Enter
5. Activate the environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

That is all.

---

# Running the tutorial Python in VS Code

If you want to run the Python files in **Visual Studio Code**, do this.

## 1. Open the `tutorials` folder in VS Code

Use:

* **File > Open Folder**

and choose:

```text
C:\maprock\timemolecules\tutorials
```

## 2. Select the Python interpreter

In VS Code:

1. Press **Ctrl+Shift+P**
2. Type:

```text
Python: Select Interpreter
```

3. Choose the interpreter at:

```text
C:\maprock\timemolecules\tutorials\.venv\Scripts\python.exe
```

If you do not see it, choose:

```text
Enter interpreter path
```

and browse to it manually.

## 3. Run the file

Open the Python file you want to run and use:

* **Run Python File**
* or right-click and choose **Run Python File in Terminal**

That will run it using the virtual environment you selected.

---

# If `python` still is not recognized

On some Windows systems, Python may be installed but not available as `python` in PowerShell.

If that happens, use the full path directly, for example:

```powershell
C:\python310\python.exe -m venv .venv
```

Also note: if you are standing in `C:\python310` and want to run `python.exe` from there, PowerShell often requires:

```powershell
.\python.exe --version
```

not just:

```powershell
python.exe --version
```

That is a PowerShell behavior, not a Python problem.

---

# Summary

From the `tutorials` folder, the usual Windows setup is:

```powershell
C:\python310\python.exe -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r ai_agent_skills\requirements.txt
```

Here’s a drop-in section for `tutorials/install_python_virtual_env.md`.

---

Yes — you’re right on both counts.

I accidentally let your local setup leak into the general instructions.

What needs fixing:

* **`C:\python310` is not typical**. That was your machine, not a user assumption.
* The activation path is only correct if the venv was created in **`tutorials`**. Since your file is `tutorials/install_python_virtual_env.md`, the instructions need to be explicit that the user should be **in the `tutorials` folder** when creating and activating it.

Here’s a corrected, **drop-in replacement** section for that file that is user-facing and general.

---

# Do I need to recreate or restart the virtual environment every time?

No. You only **create** the virtual environment once.

From the **`tutorials`** folder, run one of these:

```powershell
py -m venv .venv
```

or, if `py` is not available but `python` is:

```powershell
python -m venv .venv
```

This creates the `.venv` folder **inside `tutorials`**.

## What you do need to do each time

Each time you:

* reboot your laptop
* open a new PowerShell window
* open a new VS Code terminal

you need to **activate** the virtual environment again for that session.

But first, make sure you are in the **`tutorials`** folder.

Then run:

```powershell
.\.venv\Scripts\Activate.ps1
```

If activation works, you will usually see something like this at the beginning of the prompt:

```text
(.venv)
```

That means the current shell is using the virtual environment.

## Simple way to think about it

* **Create** the virtual environment once
* **Activate** it each time you start a new session

The virtual environment stays on disk after it is created. Rebooting the computer does **not** delete it. Activation just tells the current PowerShell or VS Code terminal to use it.

## Typical daily use

After the virtual environment has already been created, the normal pattern is:

1. Open File Explorer
2. Go to the `tutorials` folder in the repository
3. Type `powershell` in the address bar
4. Press **Enter**
5. Run:

```powershell
.\.venv\Scripts\Activate.ps1
```

That is all you need to do before running the tutorial Python files.

## If PowerShell blocks activation

If PowerShell says script execution is disabled, run this once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then answer:

```text
Y
```

and activate again:

```powershell
.\.venv\Scripts\Activate.ps1
```

## VS Code note

If you are using VS Code and have already selected the interpreter inside:

```text
tutorials\.venv\Scripts\python.exe
```

then VS Code may use that environment automatically for running Python files. Even so, it is still normal for a new terminal window to require activation if you want the terminal itself to use the same environment.

## Important note

These instructions assume the virtual environment was created from the **`tutorials`** folder. If you created `.venv` somewhere else, the activation path will be different.

---

And if you want, I’d also tighten the earlier creation section so it does **not** imply a hardcoded Python location. The safer wording is:

````md
From the `tutorials` folder, create the virtual environment with:

```powershell
py -m venv .venv
````

If `py` is not available, try:

```powershell
python -m venv .venv
```

If neither works, Python may not be installed or may not be available from your command line.

```

The core fix is: **instructions should be relative to `tutorials`, not to your personal Python install path.**
```
