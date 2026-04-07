## Connecting to TimeSolution

TimeSolution is a SQL-based system. In its current sample implementation, it runs on **SQL Server**, so a connection must be set up with valid credentials and network access. In practice, those credentials and connection details are typically provisioned by a human administrator, not by the AI agent itself.

The agent should assume that database access is already configured and should fail clearly if it is not.

### What access means

Access to TimeSolution usually involves more than just a username and password. The runtime environment may also need:

- a reachable server or endpoint
- a database name
- a driver or connector appropriate to the platform
- authentication credentials or integrated identity
- network/firewall permission
- database permissions on the approved interface objects
- row-level visibility rules, such as `AccessBitmap` filtering in SQL Server

In the intended access model, the agent or application should **not** connect directly to base tables. Instead, access should be granted only through curated database interface objects such as:

- views
- stored procedures
- table-valued functions
- scalar functions

The base tables are intended to remain locked down.

### Platform connection and access summary

| Platform | Current support in TimeSolution sample code | Typical connection method | Credentials or identity needed | Other required setup | What access usually means |
|---|---|---|---|---|---|
| SQL Server | Implemented | ODBC / SQL Server driver | SQL login or Windows / integrated identity | Server name, database name, installed driver, network access, firewall rules | Permission to connect to the database, plus `SELECT` on approved views and `EXECUTE` on approved stored procedures and functions. Base tables remain restricted. Row visibility may also be filtered by `AccessBitmap` logic. |
| Azure SQL Managed Instance | Planned / expected to be close to SQL Server | ODBC / SQL Server driver | SQL login, Microsoft Entra ID, or managed identity depending on deployment | Managed instance endpoint, database name, driver, private networking / firewall / VNet rules | Similar to SQL Server: the caller should access approved views, procedures, and functions rather than base tables. Row-level visibility logic may still apply. Usually the easiest Azure target because it is closest to SQL Server behavior. |
| Azure Synapse | Planned, but code not yet implemented | Synapse-compatible SQL connection | SQL credentials, Entra ID, or workspace identity depending on architecture | Dedicated or serverless endpoint, workspace/network access, possible code refactoring for unsupported SQL Server features | Access means both platform connectivity and permissions on approved SQL interface objects. Some SQL Server patterns may need to be rewritten before TimeSolution objects can run there. |
| Snowflake | Planned, but code not yet implemented | Snowflake connector / ODBC / JDBC | Snowflake username-password, SSO, key-pair auth, or service identity | Account identifier, warehouse, database, schema, role, network policy, connector setup | Access includes not only login, but also the correct role, warehouse, database, and schema privileges. The intended pattern is still controlled access through approved views, procedures, and functions rather than raw tables. SQL Server-specific code patterns will need conversion. |

### Required information for a connection

| Category | Example values | Why it is needed |
|---|---|---|
| Server / endpoint | `myserver`, managed instance DNS name, Synapse endpoint, Snowflake account URL | Tells the client where to connect |
| Database name | `TimeSolution` | Identifies the target database |
| Authentication method | SQL login, integrated auth, Entra ID, Snowflake role-based login | Determines how identity is established |
| Username / principal | SQL user, service account, Entra identity, Snowflake user | Identifies who is connecting |
| Secret or credential material | Password, token, key-pair, managed identity | Proves the identity is allowed to connect |
| Driver / connector | SQL Server ODBC Driver 18, Snowflake Python connector | Allows the client application to talk to the platform |
| Network access | Firewall opening, VNet/private endpoint, VPN, allowlist | Prevents connection failures even when credentials are valid |
| Database permissions | `SELECT` on approved views, `EXECUTE` on approved procedures/functions | Controls what the user can actually do after connecting |
| Row-level visibility rules | `AccessBitmap`, security function, policy logic | Controls what subset of the data the caller is allowed to see |

### Approved object-level access inside TimeSolution

| Object type | Typical permission needed | Meaning |
|---|---|---|
| View | `SELECT` | Read curated output exposed for consumers and agents |
| Stored procedure | `EXECUTE` | Run approved operations and retrieve result sets through controlled logic |
| Scalar function | Permission to execute or reference, depending on platform and usage pattern | Use approved scalar logic without exposing base tables |
| Table-valued function | `SELECT` or function access depending on platform and usage pattern | Query a controlled table-shaped result |
| Base tables | No direct access for normal consumers | Base storage remains locked down and is intended to be accessed only indirectly through approved interface objects |

### Access model intent

| Design choice | Meaning |
|---|---|
| Views are exposed | Consumers can query curated projections without reading base tables directly |
| Stored procedures are exposed | Consumers can perform approved retrieval or processing steps through controlled logic |
| TVFs and scalar functions are exposed | Consumers can reuse approved logic in a composable way |
| Base tables are locked down | The schema can be protected from accidental misuse, overreach, or uncontrolled querying |
| Security logic stays centralized | Row visibility and business rules can be enforced consistently in the exposed objects |

### What an AI agent should assume

| Situation | Recommended agent assumption |
|---|---|
| Credentials are missing | The agent should not invent them; it should report that database access has not been configured. |
| Driver is missing | The agent should report that the client environment is incomplete. |
| Login works but query fails | The agent should assume object-level permissions may be missing on the approved views, procedures, or functions. |
| Direct table access fails | This is expected in the intended security model. The agent should use the approved interface objects instead. |
| Some rows are missing | The agent should consider that row-level filtering such as `AccessBitmap` may be in effect. |
| Platform is Synapse or Snowflake | The agent should assume that some TimeSolution SQL Server code may need to be adapted before execution. |

### Practical note

For the current sample implementation, **SQL Server** is the active reference platform. **Azure SQL Managed Instance** is expected to be the most natural near-term deployment target because it is closest to SQL Server behavior. **Azure Synapse** and **Snowflake** are important target platforms, but they should presently be treated as planned targets that will require connector setup, security configuration, and some SQL adaptation before full support is available.

The intended operational model is that consumers and agents work through **approved views, stored procedures, and functions**, while the underlying base tables remain protected.
