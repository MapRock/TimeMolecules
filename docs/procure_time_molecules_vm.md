**Recommended Notes: Procuring & Using the TimeMolecules Ready-to-Run Azure VM**  
*(Strongly optimized for best experience with cloud LLMs)*

**Last Updated:** May 1, 2026

This is the **easiest and fastest** way to run the TimeMolecules tutorials and book examples. You get your own fully pre-configured Windows 11 VM with VS Code, Python, SQL Server, and all dependencies already installed.

**Important Recommendation on LLM Choice**  
The VM image was deliberately chosen on the **Standard D4ds v4** size to give you the best balance of **cost** (~$0.27/hour) and **speed**.  
**Ollama (local LLM) does NOT perform well on this VM** — it feels sluggish and is not recommended.  

**Strongly recommend using OpenAI or Grok instead.**  
Just set your `OPENAI_API_KEY` (works for both OpenAI and Grok via the OpenAI-compatible endpoint) and you’ll get fast, high-quality responses with zero local overhead. This is the intended and smoothest experience.

---

### Step 1: Create Your VM (≈5 minutes)

1. Go to [https://portal.azure.com](https://portal.azure.com) and sign in (free trial account works fine).
2. Search for **“Virtual machines”** → **Create** → **Azure Virtual Machine**.
3. On the **Basics** tab:
   - **Image**: Search for and select **TimeSolution-Book-Tutorial-V1** (or the exact name published by the author).
   - **Size**: Start with **Standard D4ds v4** (perfect cost/speed balance).
   - **Username**: `tmuser`
   - **Password**: Choose a strong password you’ll remember.
   - **Public inbound ports**: RDP should already be selected.
4. Click **Review + create** → **Create**.

---

### Step 2: Connect to Your VM

1. After creation, click **Start** on the Overview page.
2. When status shows **Running**, click **Connect** → **RDP** → **Download RDP file**.
3. Open the RDP file and log in as:
   - **Username**: `tmuser`
   - **Password**: the one you set.

---

### Step 3: Activate the Virtual Environment & Get Started

When you first log in, Visual Studio Code should already be open in the correct folder:  
`C:\MapRock\TimeMolecules\tutorials\ai_agent_skills`

The Python virtual environment (`.venv`) lives in this folder (or its `scripts` subfolder as noted below).

#### Option A: Activate .venv in Visual Studio Code (Recommended)
1. VS Code should already show **(.venv)** in the bottom-left terminal prompt.  
   If it doesn’t, open the integrated terminal (`Ctrl + ``) and run:
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```
2. You’re now ready to run Python code inside VS Code.

#### Option B: Activate .venv in PowerShell (Standalone)
If you prefer a separate PowerShell window or need to run scripts outside VS Code:

1. Open **PowerShell** (search for it in the Start menu).
2. Navigate to the scripts folder:
   ```powershell
   cd C:\MapRock\TimeMolecules\tutorials\ai_agent_skills\scripts
   ```
3. Activate the virtual environment:
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```
4. You will see `(.venv)` appear at the start of your prompt.

---

### Step 4: Run the AI Agent Demo (Super Simple)

With the `.venv` activated:

```powershell
python time_molecules_agent_demo.py
```

A GUI window will open — start chatting with the agent!

---

### Step 5: Configure OpenAI or Grok (Critical for Best Performance)

1. In VS Code, open the `.env` file (it’s in the project root).
2. Set your key like this:
   ```env
   OPENAI_API_KEY=sk-proj-....................................
   ```
   (You can use either your OpenAI key **or** Grok API key — both work seamlessly through the OpenAI client.)

3. Save the file. No restart needed — the demo will automatically use the cloud LLM.

**Why this is strongly recommended**: Ollama runs poorly on the cost-balanced D4ds v4 VM. Cloud models (OpenAI/Grok) are dramatically faster, more reliable, and require zero extra VM resources.

---

### Step 6: Using SQL Server Management Studio (SSMS)

The VM comes with **SQL Server** and **SQL Server Management Studio** pre-installed.

1. Search for **“SQL Server Management Studio”** in the Windows Start menu and launch it.
2. Connect using:
   - **Server name**: `.` or `localhost`
   - **Authentication**: Windows Authentication (no extra credentials needed)
3. You can now run any SQL queries side-by-side with your Python code in VS Code.

---

### Step 7: Stop the VM When Finished (Save Money!)

You are only charged while the VM is **Running**.

- Go back to the Azure Portal → select your VM → click **Stop**.
- Cost drops to **$0**.
- Start it again anytime — everything you saved is still there.

**Optional performance boost**: If you want even snappier responses, resize the VM to **Standard D8ds v4** (8 vCPU) in the Azure Portal. Still very affordable.

---

**Questions or issues?**  
Open an issue on the GitHub repo: https://github.com/MapRock/TimeMolecules

