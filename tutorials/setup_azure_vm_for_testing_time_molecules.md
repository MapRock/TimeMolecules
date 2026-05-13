
# Setup Azure Windows VM for TimeMolecules (Full Book + Tutorial Environment)


This is the starting point of the guide that shows you how to create a clean Azure Windows Virtual Machine, then install the dev environment on it.  

It is the recommended method for:
- Readers of the book who need the full install (SQL Server + SSMS + Neo4j + restored database)
- People following the AI Agent tutorial
- Anyone who wants a 100% fresh test environment

As of May 24, 2026, there will be an option to select a [pre-configured Azure Windows VM](https://github.com/MapRock/TimeMolecules/blob/main/docs/procure_time_molecules_vm.md). This avoids having to install the dev environment.

---

## Why Use an Azure VM?

- Completely clean Windows environment (no conflicts with your local machine)
- Easy to reset or share with others
- Can be captured as a reusable public image so others can deploy in minutes
- Perfect for validating installation instructions

---

## 1. Create the Virtual Machine (Recommended Settings)

In the Azure Portal, go to **Home** → select **Virtual machines** → click **Create** → **Virtual Machine**.

Use these exact settings

Basics page:

| Setting                          | Recommended Value                                      | Notes |
|----------------------------------|--------------------------------------------------------|-------|
| **Subscription**                   | Enter your subscription                   |  |
| **Resource Group**                   | Time_Molecules                   |  |
| **Region**                       | West US (or closest to you)                           | — |
| **Virtual Machine Name**                   | TimeSolution-Book-Tutorial-V1        | Whatever you want |
| **Image**                   | Windows Server 2025 Datacenter - x64 Gen2            | Best compatibility |
| **Size**                         | **Standard D4ds v4** (4 vCPU, 16 GiB memory)         | Ideal for SQL Server, Ollama, Neo4j |
| **Username**                     | tmuser                          | Use a generic name (not your personal name) |
| **Password**                     | Your own strong password                          | |
| **Public inbound ports**         | Allow selected ports RDP (3389)                                    | Only for testing |
| **Azure Spot**                   | Unchecked                                                    | — |
| **Licensing**                   | Unchecked                                                   | IF you do not have an existing Windows Server License |


2nd page: Disks
| Setting                          | Recommended Value                                      | Notes |
|----------------------------------|--------------------------------------------------------|-------|
| **OS Disk Size**            | Image Default (127 GiB)             | — |
| **OS Disk Type**            | Standard SSD LRS, Image default (128 GB+)             | — |

3rd page: Networking
| Setting                          | Recommended Value                                      | Notes |
|----------------------------------|--------------------------------------------------------|-------|
| **Virtual Network*            | TimeSolution-vnet             | — |


Click **Review + Create". **Expected hourly cost while running:** ~$0.45 USD/hr (you are only charged while the VM is **Running**), at the time of writing, May 13, 2026. Please double-check the rates!

Click **Create**. This will take a few minutes.

### Notes

#### Why Windows Server 2025 (instead of Windows 11)?

I chose **Windows Server 2025 Datacenter with Desktop Experience** as the base for the official TimeMolecules tutorial VM for one primary reason:

**Simpler and safer licensing for who I believe to be the typical reader of <i>Time Molecules</i>.**

Windows 11 (a client OS) requires you to confirm that you already own a qualifying license with multi-tenant hosting rights (Microsoft 365 E3/E5, Windows Enterprise E3/E5, Windows VDA, etc.). Most individual developers, hobbyists, students, and small teams do **not** have these licenses, which leads to confusion, extra steps, and the risk of accidentally violating Microsoft’s terms.

With Windows Server 2025 the operating system license is **included** in the Azure hourly price. You can create the VM without checking any special licensing boxes or worrying about compliance.

**Trade-off**: It costs a bit more per hour than a Windows 11 VM, but it gives the vast majority of people following this tutorial the smoothest, least frustrating experience.

---

## 2. Cost Management (Very Important)

- You are **only charged** while the VM status shows **Running**.
- As soon as the VM finishes deploying, **immediately click Stop** in the Azure Portal (this deallocates it).
- Compute cost drops to **$0.00/hr**.
- All files, databases, and installed software remain safe.
- Only start the VM again when you need to work on it.

---

## 3. Connect to the VM and Install the Full Environment

1. In resource page of your VM in the Azure Portal, click **Start** the VM (if it is stopped).
2. Click **Connect** → **Download RDP file** → **Open file** and log in with the username and password you chose.
3. **Inside the VM**, open Microsfot Edge and follow the main installation guide:

   → **https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.md**

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
   .\.venv\Scripts\Activate.ps1
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
cd C:\MapRock\TimeMolecules\tutorials; .\.venv\Scripts\Activate.ps1; code .
```




