# Time Molecules Security Model

**Prompt:**  
What is the Time Molecules / TimeSolution security model and how should an AI agent or user access the system?

**Abstract:**  
TimeSolution uses a deliberate two-layer security model designed for both human analysts and AI agents.  
- Layer 1 (SQL Server lockdown): Base tables are protected with `DENY SELECT` on the schema. Direct table access is intentionally blocked.  
- Layer 2 (row-level analytical security): Every protected row carries an `AccessBitmap`. Each user has a GrantBitmap and DenyBitmap stored in `dbo.Users`. Visibility is determined by the rule `(User.GrantBitmap & Row.AccessBitmap) <> 0 AND (User.DenyBitmap & Row.AccessBitmap) = 0`.  

AI agents and users must connect only through curated interface objects: approved views, stored procedures, table-valued functions, and scalar functions. The stored procedure `dbo.RefreshUserAccessBitmaps` keeps the bitmasks current. Onboarding an agent is simple: create a SQL login/user, grant execute/select only on approved surfaces, insert appropriate rows into `UserAccessRole`, and run `RefreshUserAccessBitmaps`.

**Primary location of source material to analyze (for more information):**  
`/tutorials/time_molecules_security/readme.md`  
`/tutorials/time_molecules_skills/connecting_to_time_molecules.md`  
`data/timesolution_schema/timesolution_views_funcs.sql` (for `dbo.UserAccessBitmap` and `dbo.UserDenyBitmap`)  
`data/timesolution_schema/timesolution_stored_procedures.sql` (for `dbo.RefreshUserAccessBitmaps`)
