## Running Time Molecules on an Azure VM

This guide walks through setting up a clean Windows virtual machine (VM) in Azure to install and test Time Molecules end-to-end. This is especially useful for validating the full setup, tutorials, and fallback modes in a fresh environment.

---

### Why use an Azure VM?

- Simulates a **new user installation**
- Catches missing dependencies and unclear steps
- Lets you test multiple configurations:
  - Full setup (SQL Server + Qdrant + LLM)
  - Partial setup (no Qdrant, JSON fallback)
  - Minimal setup (local embeddings only)

---

## 1. Create the Virtual Machine

In the Azure Portal:

1. Go to **Virtual Machines**
2. Click **Create → Azure Virtual Machine**

### Recommended settings

**Image**
- `Windows 11 Pro` *(preferred for development)*
  - or `Windows Server 2022`

**Size**
- Recommended: `Standard B4ms`
  - 4 vCPU, 16 GB RAM
  - Good balance of cost and performance

**Disk**
- 128 GB Standard SSD is sufficient

**Networking**
- Allow **RDP (port 3389)**

Create a username and password, then deploy.

---

## 2. Connect to the VM

1. After deployment, open the VM in Azure Portal
2. Click **Connect → RDP**
3. Download the `.rdp` file
4. Open it and log in

You now have a full Windows desktop.

---

## 3. Install Required Software

Inside the VM:

### Core tools
- Git
- Visual Studio Code
- Python 3.10+

### Time Molecules
```bash
git clone https://github.com/MapRock/TimeMolecules.git
cd TimeMolecules/tutorials
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
````

### Data layer

* Install **SQL Server Developer Edition**
* Restore the **TimeSolution** database

### AI / embeddings

* Install **Ollama** (full runtime required, not just Python library)
* Pull embedding model (example):

```bash
ollama pull nomic-embed-text
```

### Optional

* Install **Qdrant** if testing full semantic retrieval

---

## 4. Run the Demo

From the tutorials directory:

```bash
python ai_agent_skills/time_molecules_agent_demo.py
```

The app will:

* Detect available components (LLM, Qdrant, JSON fallback)
* Adjust features automatically
* Log decisions in the console

---

## 5. Understanding VM Costs (Important)

### Running VM

You are billed for:

* CPU and memory (~$0.15–0.20/hour for B4ms)
* Disk storage (~$5–10/month)

### Stopping the VM

There are **two types of stop**:

#### ❌ Shutdown inside Windows

* VM still allocated
* **You are still charged**

#### ✅ Stop (Deallocate) in Azure Portal

* Releases CPU and memory
* **Compute cost drops to $0**
* Disk and files are preserved

To deallocate:

1. Go to VM in Azure Portal
2. Click **Stop**
3. Wait for status:

   > `Stopped (deallocated)`

---

## 6. What Happens When Deallocated?

### You keep:

* All files
* Installed software
* SQL Server databases
* Python environment
* Time Molecules setup

### You lose:

* Running processes
* Temporary in-memory state

### Note:

* Public IP address may change on restart

---

## 7. Restarting the VM

1. Click **Start** in Azure Portal
2. Wait ~30–60 seconds
3. Reconnect via RDP

Everything resumes where you left off.

---

## 8. Recommended Usage Pattern

* Start VM when testing
* Stop (deallocate) when finished

Typical cost:

* ~$10–$40/month depending on usage

---

## 9. Optional: Snapshot for Reuse

Once setup is complete:

* Create a VM image or snapshot
* Quickly spin up fresh environments for testing

---

## Summary

Running Time Molecules on an Azure VM provides a clean, controlled environment to validate installation, tutorials, and fallback modes. By using **Stop (Deallocate)** when not in use, you can keep costs low while maintaining a fully configured test system.

```
```
