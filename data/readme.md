# TimeSolution.bak - Official Sample Database for Time Molecules

This `.bak` file is the official backup used for tutorials and examples in the book  
**"Time Molecules" by Eugene Asahara** (Technics Publications, 2025).

---

## 🔐 File Authenticity and Signature Verification

To ensure that this file is genuine and hasn't been tampered with, a digital signature (`.asc`) is provided.
The current file was <b>created on May 30, 2025 at 6:02am US MT.</b>

### 📄 Included Files (download into c:/MapRock/TimeMolecules/data)

- `TimeSolution.bak` — SQL Server backup file. Download from onedrive storage: https://1drv.ms/u/c/7d94c9ab48b30303/EQDqhzDQZ4RGnjKh-NSXabsBhVUG3QSfMlAcqmz_0CF4Kw?e=hyogeA
- `TimeSolution.bak.asc` — Digital signature file (signed by Eugene Asahara)
- `publickey.asc` — Public key to verify the signature
- `restore.sql` — Example script to restore the database
- `LicenseAndDisclaimer.txt` — Legal and usage notes

---

## ✅ Verifying the Signature (Optional, for Advanced Users)

To verify that the backup file was signed by Eugene Asahara:

### 1. Install GPG

- **Windows**: [https://git-scm.com/download/win](https://git-scm.com/download/win)
- **Mac**: `brew install gnupg`
- **Linux**: `sudo apt install gnupg`

### 2. Import the public key

```bash
gpg --import publickey.asc
