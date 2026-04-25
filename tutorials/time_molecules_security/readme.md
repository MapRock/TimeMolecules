
# Time Molecules Security Model (Grant + Deny Bitmaps)

The TimeSolution uses a **two-layer security model**:

1. **SQL Server authentication + permission lockdown** (prevents direct table access)
2. **Analytical access control via bitmaps** (`AccessBitmap` = grants, `DenyBitmap` = explicit denies)

This design keeps the underlying tables completely locked down while giving fine-grained, row-level control over what an AI agent (or any user) can see in views, TVFs, and stored procedures.

## 1. SQL Server Level Security (Lockdown)

Tables (`EventsFact`, `Cases`, `Models`, `CasePropertiesParsed`, etc.) are **never** directly accessible to normal users or AI agents.

```sql
-- 1. Create SQL Login (done once)
CREATE LOGIN [EAA2024\AI-Agent] FROM WINDOWS;

-- 2. Create DB user and map it
USE [TimeSolution];
CREATE USER [EAA2024\AI-Agent] FOR LOGIN [EAA2024\AI-Agent];

-- 3. Lock down tables (admin/super-role only)
DENY SELECT ON SCHEMA::dbo TO [EAA2024\AI-Agent];

-- 4. Grant access only to approved surfaces
GRANT SELECT ON vwEventsFact TO [EAA2024\AI-Agent];
GRANT EXECUTE ON dbo.RefreshUserAccessBitmaps TO [EAA2024\AI-Agent];
GRANT EXECUTE ON dbo.UserAccessBitmap TO [EAA2024\AI-Agent];
GRANT EXECUTE ON dbo.UserDenyBitmap TO [EAA2024\AI-Agent];
-- (repeat for every approved view/proc/TVF)
```

## 2. Analytical Access Bitmaps (The Real Security Layer)

Each row that needs protection carries an `AccessBitmap` column.  
Each user has two bitmasks:

- `Users.AccessBitmap` → **GrantBitmap** (roles the user *has*)
- `Users.DenyBitmap` → **explicit Deny roles**

**Visibility rule (applied everywhere):**

```sql
(User.GrantBitmap & Row.AccessBitmap) <> 0      -- at least one required role is granted
AND
(User.DenyBitmap & Row.AccessBitmap) = 0        -- NO denied role overlaps any required role
```

### Current Example Data (from your snapshot)

**`dbo.Access` (master role list)**

| AccessID | Description          | IsActive |
|----------|----------------------|----------|
| 1        | Restaurant Worker    | 1        |
| 2        | Truck Route Manager  | 1        |
| 3        | Web Site Admin       | 1        |
| 8        | private Stuff        | 1        |

**`dbo.UserAccessRole` for UserID = 1**

| UserID | AccessID | Granted | CreateDate          | LastUpdate          |
|--------|----------|---------|---------------------|---------------------|
| 1      | 1        | 1       | 2026-04-11 ...     | 2026-04-11 ...     |
| 1      | 2        | 1       | 2026-04-11 ...     | 2026-04-11 ...     |
| 1      | 3        | 1       | 2026-04-11 ...     | 2026-04-11 ...     |
| 1      | 8        | **0**   | 2026-04-25 ...     | 2026-04-25 ...     |

**`dbo.Users` (after refresh)**

| SUSER_NAME       | AccessBitmap | DenyBitmap | UserID | LastUpdate          |
|------------------|--------------|------------|--------|---------------------|
| EAA2024\easah    | 7            | **128**    | 1      | 2026-04-25 ...     |

(`AccessBitmap = 7` = bits 1+2+4 → roles 1, 2, 3 granted. `DenyBitmap = 128` = bit 8 denied.)

## 3. Onboarding an AI Agent – Step-by-Step

1. Create the SQL login and user (see section 1 above).
2. Assign roles (grants and denies):

```sql
INSERT INTO dbo.UserAccessRole (UserID, AccessID, Granted)
VALUES 
    (1, 1, 1),   -- grant Restaurant Worker
    (1, 2, 1),   -- grant Truck Route Manager
    (1, 3, 1),   -- grant Web Site Admin
    (1, 8, 0);   -- explicitly deny "private Stuff"
```

3. Refresh the bitmaps:

```sql
EXEC dbo.RefreshUserAccessBitmaps @UserID = 1, @DisplayResults = 1;
```

4. Verify:

```sql
SELECT SUSER_NAME, AccessBitmap, DenyBitmap, LastUpdate 
FROM dbo.Users 
WHERE UserID = 1;
```

## 4. RefreshUserAccessBitmaps Stored Procedure

This is the **official** proc that flattens `UserAccessRole` into the two user bitmaps. It is already updated in your database.

```sql
    EXEC dbo.RefreshUserAccessBitmaps
        @UserID = 1,
        @DisplayResults = 1;
```

Run it after any change to `UserAccessRole`.

## 5. How Security Is Applied – Example View: vwEventsFact

```sql
CREATE OR ALTER VIEW [dbo].[vwEventsFact]
AS
WITH UserSecurity AS (
    SELECT GrantBitmap, DenyBitmap FROM UserAccessDeny()

)
SELECT
e.CaseID,
e.Event,
e.EventDate,
CONVERT(INT, CONVERT(VARCHAR(8), e.EventDate, 112)) AS DateKey,
CONVERT(INT, REPLACE(CONVERT(VARCHAR(8), e.EventDate, 108), ':', '')) AS TimeKey,
e.CaseOrdinal, e.EventID, e.SourceID, e.AggregationTypeID, at.Description AS AggDesc, e.CreateDate
FROM  dbo.EventsFact AS e WITH (NOLOCK) 
CROSS JOIN UserSecurity us
LEFT OUTER JOIN  dbo.AggregationTypes AS at WITH (NOLOCK) ON at.AggregationTypeID = e.AggregationTypeID
WHERE 
    (us.GrantBitmap & e.AccessBitmap) <> 0      -- at least one grant
    AND (us.DenyBitmap & e.AccessBitmap) = 0;   -- NO deny overlap
```

**Test it:**

```sql
-- This will return rows only where the user has at least one granted role
-- AND none of the required roles are denied.
SELECT TOP 100 * FROM vwEventsFact;
```

The same pattern (`dbo.UserAccessBitmap()` + `dbo.UserDenyBitmap()`) is used in **every** view, TVF, and secured stored procedure.

