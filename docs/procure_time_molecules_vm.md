
# How to Use the TimeMolecules Ready-to-Run Azure VM Image

**Last Updated:** April 30, 2026

This is the **easiest way** for readers to try the TimeMolecules tutorials and book examples.

You will get your **own personal copy** of a fully pre-configured Windows 11 machine with everything already installed.

**All you really need to do is open Visual Studio Code and run the demo.**

---

## Step 1: Create Your Own VM from the Image (5 minutes)

1. Go to [https://portal.azure.com](https://portal.azure.com) and sign in (free account is fine).
2. Search for **"Virtual machines"** → **Create** → **Azure Virtual Machine**.
3. On the **Basics** tab:
   - **Image**: Search for and select the image named **`TimeSolution-Book-Tutorial-V1`** (or the exact name the author publishes)
   - **Size**: Start with **Standard D4ds v4** (you can resize later for faster performance)
   - **Username**: `tmuser` (this is the pre-configured username on the image)
   - **Password**: Choose a strong password you will remember
   - **Public inbound ports**: RDP should already be selected

4. Click **Review + create** → **Create**.

---

## Step 2: Connect to Your VM

1. After the VM is created, click **Start** on the Overview page.
2. Once it says **Running**, click **Connect** → **RDP** → **Download RDP file**.
3. Open the downloaded file and log in with:
   - **Username**: `tmuser`
   - **Password**: the one you chose in Step 1

---

## Step 3: Get Started (Super Simple)

When you log in you will see:
- Visual Studio Code is already open in the correct folder:  
  `C:\MapRock\TimeMolecules\tutorials\ai_agent_skills`

**To run the AI Agent Demo:**

1. In the terminal at the bottom of VS Code you should already see `(.venv)` (the virtual environment is active).
2. If not, run this once:
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```
3. Run the demo:
   ```powershell
   python time_molecules_agent_demo.py
   ```

A GUI window will open. Start asking questions!

---

## Step 4: Stop the VM When You’re Done (Important!)

You are only charged while the VM is **Running** (~$0.27/hour for the default size).

- When finished, go back to the Azure Portal → select your VM → click **Stop**.
- This drops your cost to $0.
- You can start it again anytime — all your work is saved.

---

## Optional Tips

- **Make it faster**: In Azure Portal → your VM → **Size** → change to **Standard D8ds v4** (8 vCPU). Recommended if Ollama feels slow.
- **Use your own OpenAI or Grok key**: Edit the `.env` file in VS Code if you prefer cloud LLM instead of local Ollama.

---

**Questions or problems?**  
Open an issue on the GitHub repo: https://github.com/MapRock/TimeMolecules

Enjoy exploring Time Molecules!
