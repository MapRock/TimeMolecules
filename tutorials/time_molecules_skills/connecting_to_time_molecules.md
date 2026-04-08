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

## MCP access for AI agents

In addition to direct database connections, TimeSolution can also be exposed to AI agents through MCP (Model Context Protocol). MCP is a standard way for agents to discover and call approved tools rather than issuing unrestricted SQL directly. For SQL Server-family deployments, Microsoft’s SQL MCP Server is now part of Data API builder and is designed to expose selected database objects to agents through a controlled interface. :contentReference[oaicite:0]{index=0}

### Why MCP may be useful for TimeSolution

For TimeSolution, MCP is not a replacement for the database. It is a controlled access layer in front of the database. This fits the intended TimeSolution access model well because agents are already expected to work through approved interface objects such as:

- views
- stored procedures
- table-valued functions
- scalar functions

rather than connecting directly to base tables. MCP can make those approved interfaces easier to expose to agent frameworks while keeping object-level permissions and access rules centralized. Microsoft’s SQL MCP Server documentation explicitly describes exposing selected tables, views, and stored procedures through configuration, with role-based access control applied consistently. :contentReference[oaicite:1]{index=1}

### SQL Server and Azure SQL Managed Instance

For SQL Server, MCP is a practical connection option today through Microsoft’s SQL MCP Server in Data API builder. Data API builder supports SQL Server and Azure SQL, and the SQL MCP Server uses the same configuration model to define the database connection and the objects that are exposed to agents. :contentReference[oaicite:2]{index=2}

Azure SQL Managed Instance should generally be treated as the most natural Azure target for TimeSolution because it is closest to SQL Server behavior. An MCP layer built with Microsoft’s SQL MCP Server should be considered viable when the managed instance is reachable and the required networking, identity, and database permissions are in place. The important practical point is that Managed Instance still requires endpoint reachability, authentication, and private networking or firewall setup like any other SQL deployment. :contentReference[oaicite:3]{index=3}

### Snowflake

Snowflake also supports MCP, but through a different platform path. Snowflake provides a Snowflake-managed MCP server and SQL support for creating MCP servers inside Snowflake. That means AI agents can connect to governed Snowflake tools and approved SQL execution paths without deploying a separate MCP layer outside Snowflake. :contentReference[oaicite:4]{index=4}

For TimeSolution specifically, Snowflake should still be treated as a target platform that may require SQL adaptation because the current sample implementation is SQL Server-based. MCP does not remove the need to adapt SQL Server-specific code patterns when moving TimeSolution logic to Snowflake. :contentReference[oaicite:5]{index=5}

### When to use MCP versus a direct connection

Use a direct database connection when:

- the runtime already has an approved connector and credentials
- the agent is expected to call a known set of procedures, views, or functions directly
- the environment is SQL Server-centric and no tool-discovery layer is needed

Use MCP when:

- the agent framework expects MCP tools
- you want object exposure and tool descriptions to be centrally configured
- you want a stronger contract around what an agent may call
- you want to expose only approved retrieval or action surfaces rather than broad SQL capability

MCP is therefore best understood as an optional agent-facing access layer for TimeSolution, not as a change to TimeSolution’s underlying security model. The same design principle still applies: expose curated interface objects and keep base tables protected. :contentReference[oaicite:6]{index=6}

### Recommended guidance for AI agents

If TimeSolution is made available through MCP, an AI agent should assume:

| Situation | Recommended agent assumption |
|---|---|
| MCP server is available | Use the advertised approved tools first instead of inventing raw SQL. |
| MCP tool call fails | Treat this as a configuration, connectivity, or permission issue and fail clearly. |
| A needed object is not exposed | Do not assume broad database access exists; report that the interface does not include the required object. |
| Results seem incomplete | Consider that role-based filtering, approved object exposure, or row-level visibility logic may be in effect. |
| Platform is Snowflake | Assume the MCP layer may be present even if TimeSolution SQL had to be adapted for the platform. |

### Practical note

For a tutorial on connecting to TimeSolution, MCP should be presented as an add-on deployment option for AI agents rather than the default connection method. The default explanation should remain direct database connectivity to approved SQL objects. Then a separate note can explain that agent-oriented deployments may expose those same approved objects through MCP for safer tool discovery and controlled execution. :contentReference[oaicite:7]{index=7}
