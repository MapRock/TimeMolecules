
# Setup Azure Windows VM for TimeMolecules (Full Book + Tutorial Environment)

<i>**Last Updated:** May 08, 2026 - This VM will be in limited beta from May 10, 2026 through May 24, 2026, then released to the general audience through the Azure Compute Gallery.</i>

This guide shows you how to create a clean Azure Virtual Machine with the **complete TimeMolecules development environment**.  
It is the recommended method for:
- Readers of the book who need the full install (SQL Server + SSMS + Neo4j + restored database)
- People following the AI Agent tutorial
- Anyone who wants a 100% fresh test environment

---

## Why Use an Azure VM?

- Completely clean Windows environment (no conflicts with your local machine)
- Easy to reset or share with others
- Can be captured as a reusable public image so others can deploy in minutes
- Perfect for validating installation instructions

---

## 1. Create the Virtual Machine (Recommended Settings)

In the Azure Portal, go to **Virtual machines** → **Create** → **Azure Virtual Machine**.

Use these exact settings:

| Setting                          | Recommended Value                                      | Notes |
|----------------------------------|--------------------------------------------------------|-------|
| **Image**                        | Windows 11 Pro, version 25H2 - Gen2                   | Best compatibility |
| **Size**                         | **Standard D4ds v4** (4 vCPU, 16 GiB memory)         | Ideal for SQL Server, Ollama, Neo4j |
| **OS Disk**                      | Standard SSD LRS, Image default (128 GB+)             | — |
| **Username**                     | tmuser                          | Use a generic name (not your personal name) |
| **Public inbound ports**         | RDP (3389)                                            | Only for testing |
| **Already have a Windows license?** | **Yes** (Windows Client)                           | Keeps hourly cost lower |
| **Region**                       | West US (or closest to you)                           | — |
| **Azure Spot**                   | No                                                    | — |

**Expected hourly cost while running:** ~$0.266 USD/hr (you are only charged while the VM is **Running**), at the time of writing, May 8, 2026. Please double-check the rates!

---

## 2. Cost Management (Very Important)

- You are **only charged** while the VM status shows **Running**.
- As soon as the VM finishes deploying, **immediately click Stop** in the Azure Portal (this deallocates it).
- Compute cost drops to **$0.00/hr**.
- All files, databases, and installed software remain safe.
- Only start the VM again when you need to work on it.

---

## 3. Connect to the VM and Install the Full Environment

1. In Azure Portal, start the VM (if it is stopped).
2. Click **Connect** → **RDP** and log in with the username and password you chose.
3. Inside the VM, follow the main installation guide:

   → **[docs/install_timemolecules_dev_env.md](../docs/install_timemolecules_dev_env.md)**

There, you will install everything needed:
- SQL Server Developer Edition (2022/2025) + **SSMS**
- Restore the `TimeSolution.bak` database
- Python 3.12 + virtual environment
- Visual Studio Code + extensions
- Git + full TimeMolecules repo
- Ollama + required models (`nomic-embed-text`, `llama3.2`)
- Neo4j Desktop (optional but included)

---

## 4. (Optional but Recommended) Capture as Reusable Public Image

Once everything is installed and you have tested the tutorial and book demos:

1. **Inside the VM** (run as Administrator):
   - Open Command Prompt and run:
     ```cmd
     %windir%\system32\sysprep\sysprep.exe /oobe /generalize /shutdown
     ```
   - The VM will shut down automatically.

2. Back in the Azure Portal:
   - Select the VM → click **Capture**
   - Choose **Community Gallery** (makes it public)
   - Give the image a clear name and description, for example:
     - Image definition: `TimeMolecules-Full-Dev-Environment`
     - Version: `1.0.0`
     - Description: “Pre-configured Windows VM with full TimeMolecules book + tutorial environment (SQL Server, SSMS, Python, Ollama, Neo4j)”


## TimeMolecules VM – Complete Daily Workflow

These are the instructions for re-connecting with the VM once you have procured it.

### 1. Daily Startup – How to Get to Work on the VM

1. **Log into the VM**  
   - On your local computer, open **Remote Desktop Connection** (search for “RDP” in the Windows Start menu).  
   - Connect using the VM’s IP address or hostname and your login credentials.

2. **Open SQL Server Management Studio (SSMS)**  
   - Click the Windows **Start** button.  
   - Type `SSMS` and press **Enter**.  
   - Open **Microsoft SQL Server Management Studio**.  
   - Connect to the server using `.` or `localhost` (or your instance name).

3. **Open PowerShell and navigate to the project**  
   - Press `Windows key`, type `PowerShell`, right-click **Windows PowerShell**, and choose **Run as administrator** (recommended).  
   - Navigate to your TimeMolecules folder (change the path if yours is different):
     ```powershell
     cd C:\MapRock\TimeMolecules\tutorials
     ```
     (or wherever you cloned the repo)

4. **Activate the Python virtual environment**
   ```powershell
   .\venv\Scripts\Activate.ps1
   ```
   - You should see `(venv)` appear at the start of the prompt when it’s activated.

5. **Open the project in Visual Studio Code**
   ```powershell
   code .
   ```
   - This opens VS Code directly in the TimeMolecules folder.
  
6. **REMEMBER to STOP the VM when you're finished!!!** See [Cost Management](#2-cost-management-very-important)

**Quick one-line startup command** (after you’re logged in):
```powershell
cd C:\MapRock\TimeMolecules\tutorials; .\venv\Scripts\Activate.ps1; code .
```




