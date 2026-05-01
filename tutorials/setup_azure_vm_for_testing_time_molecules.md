
# Setup Azure Windows VM for TimeMolecules (Full Book + Tutorial Environment)

**Last Updated:** April 30, 2026

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
| **Username**                     | `timemolecules` or `devuser`                          | Use a generic name (not your personal name) |
| **Public inbound ports**         | RDP (3389)                                            | Only for testing |
| **Already have a Windows license?** | **Yes** (Windows Client)                           | Keeps hourly cost lower |
| **Region**                       | West US (or closest to you)                           | — |
| **Azure Spot**                   | No                                                    | — |

**Expected hourly cost while running:** ~$0.266 USD/hr (you are only charged while the VM is **Running**).

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

This installs everything needed:
- SQL Server Developer Edition + **SSMS**
- Restore the `TimeSolution.bak` database
- Python 3.12 + virtual environment
- Visual Studio Code + extensions
- Git + full TimeMolecules repo
- Ollama + required models (`nomic-embed-text`, `llama3.2`)
- Neo4j Desktop (optional but included)

**Tip:** Create the folder `C:\MapRock\TimeMolecules` and clone the repo there.

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


