
# AI Agent Skill: Understand TimeSolution Database Schemas

**Purpose:**  
Give an AI agent immediate, authoritative knowledge of the logical organization of the TimeSolution database so it can navigate, query, and reason about the system intelligently from a cold start.

### Why This Skill Matters
TimeSolution organizes its objects into **SQL Server schemas** rather than one giant `dbo` schema. Each schema has a well-defined purpose. Knowing which schema does what is one of the fastest ways for an agent to:
- Decide where to look for raw events, processed facts, dimensions, temporary work tables, etc.
- Understand the data flow (ETL → STAGE → core TimeSolution → FACT/DIM → downstream layers)
- Generate correct `SELECT`, `JOIN`, or metadata queries

### Core Knowledge – TimeSolution Schemas

| SchemaName | Description |
|------------|-------------|
| **APP**    | Specialty tables that are **not** part of the official TimeSolution database. `APP` can stand for Application or even Appendix. These are custom or extension tables. |
| **DIM**    | **Dimensions** created from case and event properties, structured as a star/snowflake schema. |
| **DV**     | **Data Vault** (hubs, satellites, links) generated from TimeSolution tables. Not part of the core TimeSolution model. The purpose is to provide a layer that feels more familiar to traditional semantic-layer / data-warehouse users. |
| **ETL**    | Tables used by an **ETL/ELT process**. These usually sit upstream of the STAGE schema and serve as the source before data lands in TimeSolution. |
| **FACT**   | **Fact tables** derived from case and event properties. Together with the DIM schema, these form the star/snowflake dimensional model. |
| **KPI**    | Related to the performance management / KPI system. Contains tables that define KPIs (including formulas for status, value, trend, target, etc.). KPIs act as the “drivers” of the system — similar to how human emotions steer behavior. |
| **STAGE**  | **Landing tables** for ETL/ELT processes. Except for `STAGE.ImportEvents`, these tables are intended to be loaded into the core TimeSolution model. |
| **WORK**   | **Temporary working tables**. Used as clean hand-off points between processes, especially in MPP (Massively Parallel Processing) environments or when breaking large stored procedures into smaller, reusable pieces. The WORK schema acts as the “interface” between modular process steps. |

### How to Dynamically Retrieve the Latest Schema Descriptions

Always verify the descriptions directly from the database (in case they have been updated):

```sql
USE [TimeSolution]
GO

-- Get all schemas that have an extended property named "Description"
SELECT 
    s.name AS SchemaName,
    CAST(ep.value AS NVARCHAR(MAX)) AS [Description]
FROM sys.schemas s
INNER JOIN sys.extended_properties ep 
    ON ep.class = 3                    -- 3 = SCHEMA
   AND ep.major_id = s.schema_id
WHERE ep.name = 'Description'
ORDER BY s.name;
```

### Recommended Next Steps for an AI Agent

1. Run the query above to confirm current descriptions.
2. Explore the most important schemas first:
   - `STAGE.ImportEvents` → raw incoming events
   - `FACT.*` and `DIM.*` → dimensional model
   - `KPI.*` → performance drivers
3. When writing queries, always prefix tables with the correct schema (e.g. `FACT.Case`, `STAGE.ImportEvents`, `WORK.TempTransitions`, etc.).
