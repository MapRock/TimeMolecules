TimeSolutionSample:
  title: "TimeSolution.bak – Official Sample Database for Time Molecules"
  author: "Eugene Asahara"
  book: "Time Molecules (Technics Publications, 2025)"
  download_url: "https://1drv.ms/u/c/7d94c9ab48b30303/EQDqhzDQZ4RGnjKh-NSXabsBhVUG3QSfMlAcqmz_0CF4Kw?e=hyogeA"
  description: >
    This .bak file is the official SQL Server backup used in tutorials and examples from the book
    'Time Molecules' by Eugene Asahara. The backup is optionally signed for authenticity.
  files:
    - name: "TimeSolution.bak"
      type: "SQL Server backup file"
    - name: "TimeSolution.bak.asc"
      type: "Detached GPG signature"
    - name: "publickeytm.asc"
      type: "Public key for GPG signature verification"
    - name: "restore.sql"
      type: "SQL script to restore database"
    - name: "LicenseAndDisclaimer.txt"
      type: "License and usage terms"
  verification:
    optional: true
    tools_required:
      - "GPG (included with Git for Windows)"
    instructions:
      - step: "Install GPG"
        details:
          Windows: "https://git-scm.com/download/win"
          Mac: "brew install gnupg"
          Linux: "sudo apt install gnupg"
      - step: "Open Git Bash and navigate to directory"
        command: "cd /c/MapRock/TimeSolution/data"
      - step: "Import public key"
        command: "gpg --import publickeytm.asc"
      - step: "Verify signature"
        command: "gpg --verify TimeSolution.bak.asc TimeSolution.bak"
      - step: "Expected result"
        message: >
          gpg: Good signature from "Eugene Asahara (For Time Molecules) <eugene@softcodedlogic.com>"
  contact:
    email: "eugene@softcodedlogic.com"
    github: "https://github.com/YourGitHub/TimeMolecules"
