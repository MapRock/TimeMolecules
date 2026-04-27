# Using the Event Ensemble (centered on the EventsFact table) for conventional time series, sequence analysis, and even Fourier transforms in TimeSolution

In TimeSolution (the SQL implementation of *Time Molecules* by Eugene Asahara / MapRock), the primary strength is **ad-hoc Markov models** — sliced, diced, and compared via the ModelEvents layer, adjacency matrices, similarity procedures, and related tools (see the companion tutorials `compare_two_markov_models.md` and `how_to_add_an_adjacency_matrix.md`).

However, the **Event Ensemble** — the dimensional foundation centered on the `EventsFact` table (and supporting tables such as `Cases`, `CaseTypes`, etc.) — deliberately preserves the raw event stream. This enables **conventional time-series analysis** (trend detection, seasonality, volume-over-time) and **sequence analysis** (ordered event paths, lag/lead patterns, simple process flows) using standard SQL constructs or lightweight helper objects.

This tutorial is written specifically for **AI agents** that query or update the TimeSolution database. It draws directly from the full TimeSolution database script (the authoritative source for table schemas, stored procedures, views, and functions) and the supplementary material in the repository at https://github.com/MapRock/TimeMolecules (particularly `data/timesolution_schema` and `book_code/sql`).

## What the Event Ensemble is for

Use the EventsFact-centered objects when an agent needs to answer questions such as:

- What is the hourly/daily volume trend for a specific event or case type?
- What are the most common event sequences (ordered paths) within a given time window?
- How long do cases typically spend between Event A and Event B (simple lag analysis)?
- Are there seasonal or cyclical patterns in event arrivals?
- How does the raw event distribution compare to the probabilistic Markov view?

This layer complements the Markov model ensemble: the Event Ensemble gives you **exact, granular history**; the Markov layer gives you **compressed, probabilistic process intelligence**.

## Prerequisites

Before an AI agent interacts with the Event Ensemble:

1. The TimeSolution database must be installed and the schema objects created from the official script in `data/timesolution_schema`.
2. The agent must have a valid connection string / credentials (as with any SQL database).
3. Relevant data must already be loaded into `EventsFact` (and related dimension tables). The script provides ingestion patterns in `book_code/sql`.
4. For time-based analysis, ensure the `EventTime` (or equivalent timestamp column) is indexed and stored in a query-friendly data type (typically `DATETIME2` or `DATETIME`).

No special permissions beyond standard `SELECT` (and `INSERT`/`UPDATE` if writing back) are required for the patterns shown here.

## Core table: `EventsFact`

The `EventsFact` table is the central fact table of the Event Ensemble. It stores individual events with the following typical structure (extracted from the database script schema):

- `EventID` (PK or surrogate key)
- `CaseID` (links to the `Cases` dimension for process instances)
- `CaseTypeID` (or similar, linking to `CaseTypes`)
- `EventName` (or `EventCode` – the business-meaningful event label)
- `EventTime` (timestamp of the event)
- Additional attributes (source system, user, location, metrics, etc.) as defined in the schema

Supporting tables (`Cases`, `CaseTypes`, etc.) provide context for filtering and grouping.

## Recommended approaches for conventional analysis

The database script includes helper objects (views, table-valued functions, and stored procedures) that simplify common time-series and sequence patterns while staying lightweight. Direct SQL against `EventsFact` is also fully supported and often the clearest route for agents.

### 1. Time-series analysis (volume, trends, buckets)

**Preferred helper** (when available in the script): Use any pre-built views or the `sp_SelectedEvents` family (shared with the Markov path) to filter the event stream, then apply standard `GROUP BY` with time bucketing.

**Direct SQL pattern** (always available):

```sql
-- Example: Daily event volume by EventName for a specific CaseType
SELECT 
    CAST(EventTime AS DATE) AS EventDate,
    EventName,
    COUNT(*) AS EventCount,
    AVG(CASE WHEN /* optional metric column exists */ THEN MetricValue ELSE NULL END) AS AvgMetric
FROM dbo.EventsFact
JOIN dbo.Cases ON EventsFact.CaseID = Cases.CaseID
WHERE CaseTypeID = 42                  -- filter by case type
  AND EventTime >= DATEADD(DAY, -90, GETDATE())
GROUP BY CAST(EventTime AS DATE), EventName
ORDER BY EventDate DESC, EventCount DESC;
```

### 2. Sequence analysis (ordered paths, lag/lead)

Use window functions for simple sequence detection:

```sql
-- Example: Event sequences with previous event and time delta
SELECT 
    CaseID,
    EventTime,
    EventName,
    LAG(EventName) OVER (PARTITION BY CaseID ORDER BY EventTime) AS PrevEvent,
    DATEDIFF(SECOND, 
             LAG(EventTime) OVER (PARTITION BY CaseID ORDER BY EventTime), 
             EventTime) AS SecondsFromPrev
FROM dbo.EventsFact
WHERE EventTime >= '2025-01-01'
ORDER BY CaseID, EventTime;
```

For higher-order sequences or frequent pattern mining, agents can materialize the result into a temporary table and apply further grouping (the script’s Markov helpers can be reused here if desired, but are not required).

## Actionable example for an AI agent

Here is a complete, copy-paste-ready workflow an agent can execute in one session:

```sql
-- Step 1: Declare parameters (agent-friendly)
DECLARE @StartDate DATETIME2 = DATEADD(DAY, -30, GETDATE());
DECLARE @CaseTypeID INT = 42;           -- example filter
DECLARE @EventSet NVARCHAR(MAX) = N'EventA,EventB,EventC';  -- optional for focused analysis

-- Step 2: Time-series volume (daily)
SELECT 
    CAST(EventTime AS DATE) AS EventDate,
    EventName,
    COUNT(*) AS EventCount
FROM dbo.EventsFact
WHERE EventTime >= @StartDate
  AND CaseTypeID = @CaseTypeID
GROUP BY CAST(EventTime AS DATE), EventName
ORDER BY EventDate DESC;

-- Step 3: Sequence analysis with deltas (top 100 longest gaps)
SELECT TOP 100
    CaseID,
    EventName,
    LAG(EventName) OVER (PARTITION BY CaseID ORDER BY EventTime) AS PrevEventName,
    DATEDIFF(MINUTE, LAG(EventTime) OVER (PARTITION BY CaseID ORDER BY EventTime), EventTime) AS MinutesDelta
FROM dbo.EventsFact
WHERE EventTime >= @StartDate
  AND CaseTypeID = @CaseTypeID
ORDER BY MinutesDelta DESC;
```

This pattern is **idempotent**, requires no writes unless the agent chooses to persist results, and works even on very large `EventsFact` tables because it leverages the natural ordering by `EventTime` and `CaseID`.

## Practical guidance for AI agents

- **Prefer the Event Ensemble** when you need **exact counts, raw timestamps, or simple aggregations**. Use the Markov layer (ModelEvents, adjacency matrix, similarity procedures) when you need **probabilistic next-event prediction or model comparison**.
- **Parameterization**: Always parameterize dates, case types, and event filters to keep queries reusable and safe.
- **Performance**: The schema is designed for O(n) single-pass processing. Index on `(CaseID, EventTime)` and `(EventTime)` where possible (the install script recommends this).
- **Security / safety**: Never use dynamic SQL with unsanitized user input. Stick to parameterized queries or the provided stored procedures/views.
- **Chaining with Markov tools**: You can feed a filtered result set from `EventsFact` directly into Markov creation procedures if you later decide to build a model from the same slice.
- **Source material**: This tutorial is derived from the official TimeSolution database script, the book *Time Molecules*, and the GitHub repository https://github.com/MapRock/TimeMolecules (see `data/timesolution_schema`, `book_code/sql`, and the `tutorials/time_molecules_skills/` folder for related skills).

By keeping both the Event Ensemble (raw, conventional) and the Markov Model Ensemble (probabilistic, ad-hoc) in the same database, TimeSolution gives agents maximum flexibility: start with exact history, then compress into models only when needed. This design is intentional and explicitly documented in the schema and book material.
