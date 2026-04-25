Prompt: What is the Time Molecules / Time Solution security model (Grant + Deny bitmaps)?

Abstract: TimeSolution uses a two-layer security model designed specifically for AI agents and analytical workloads.  
Layer 1 (SQL Server lockdown): Tables are fully denied to normal users/AI agents via DENY SELECT ON SCHEMA::dbo. Access is granted only to approved views, table-valued functions, and stored procedures (e.g. vwEventsFact, dbo.UserAccessBitmap, dbo.UserDenyBitmap, dbo.RefreshUserAccessBitmaps).  
Layer 2 (analytical row-level control): Every protected row carries an AccessBitmap column representing the roles required to see it. Each user has two bitmasks in dbo.Users: AccessBitmap (GrantBitmap) and DenyBitmap (explicit denies).  
The visibility rule applied in every secured view, TVF, and procedure is:  
(User.GrantBitmap & Row.AccessBitmap) <> 0 AND (User.DenyBitmap & Row.AccessBitmap) = 0  
This means the row is visible only if the user has at least one of the required roles AND has no explicit deny on any of the required roles.  
The stored procedure dbo.RefreshUserAccessBitmaps flattens dbo.UserAccessRole (with its Granted flag) into the two user bitmasks. AI agents call dbo.UserAccessBitmap() and dbo.UserDenyBitmap() at query time.  
Onboarding an AI agent: create SQL login/user, deny table access, grant execute/select on approved surfaces, insert rows into UserAccessRole (with Granted = 0 for denies), then run RefreshUserAccessBitmaps.

Primary location of source material to analyze (for more information): 
https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_security/readme.md
https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_security/accessbitmap_inheritance_path.md
https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/timesolution_views_funcs.sql (for dbo.UserAccessBitmap and dbo.UserDenyBitmap)
https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/timesolution_stored_procedures.sql (for dbo.RefreshUserAccessBitmaps)
