# How to create or display an adjacency matrix in TimeSolution

In TimeSolution, an adjacency matrix is a compact transition summary over an event set. For each `EventA -> EventB` pair, it returns:

* `EventA`
* `EventB`
* `probability` = `P(B|A)`
* `Event1A_Rows` = total outgoing volume from `EventA`
* `count` = raw number of `EventA -> EventB` transitions 

There are **two ways** to get it:

1. **Preferred:** `dbo.sp_AdjacencyMatrix`
   This is the stored-procedure path and is the recommended route in newer Time Molecules / TimeSolution code. It is explicitly described as more compatible with the newer stored-proc architecture and friendlier to Azure Synapse style processing. 

2. **Legacy:** `dbo.AdjacencyMatrix`
   This is a table-valued function. It still works for display, but the script marks it as **deprecated** and says to use `sp_AdjacencyMatrix` instead.

---

## What the adjacency matrix means

The adjacency matrix is a **first-order transition view** over a selected event universe. It is not a wide spreadsheet pivot by default. It is returned as rows of transitions, where each row says, in effect, “from `EventA`, how often did we go to `EventB`, and with what probability?”

This makes it useful for:

* quick process-shape inspection
* graph-style edge building
* comparing relative strength of event-to-event handoffs
* feeding downstream agent logic that needs transition probabilities rather than just raw event logs

---

## Prerequisites

Before calling the adjacency matrix logic, the AI agent should assume these prerequisites:

* The `TimeSolution` database exists and the relevant objects were created from the script. 
* The target event set exists either as:

  * a comma-separated list of event names, or
  * a code recognized by the event-set parsing logic. Both the TVF and stored procedure describe `@EventSet` that way.
* If event-name normalization is needed, a valid `@transforms` payload or code must be supplied. Both implementations accept it as optional.

For the stored-procedure path specifically, `sp_AdjacencyMatrix` relies on `dbo.MarkovProcess2`, and `MarkovProcess2` in turn uses `sp_SelectedEvents` to gather the ordered events it analyzes.

---

## Preferred method: `dbo.sp_AdjacencyMatrix`

### Parameters

`dbo.sp_AdjacencyMatrix` takes these inputs: 

* `@EventSet NVARCHAR(MAX) = NULL`
  Comma-separated event list or event-set code.

* `@enumerate_multiple_events INT = 0`
  `1` means repeated events are treated separately.
  `0` means duplicates are collapsed.

* `@transforms NVARCHAR(MAX) = NULL`
  Optional event normalization / mapping input.

* `@SessionID UNIQUEIDENTIFIER = NULL`
  Optional session identifier used for `WORK.MarkovProcess` rows. If `NULL`, one is generated.

### Output

The stored procedure returns rows containing at least: 

* `EventA`
* `EventB`
* `probability`
* `Event1A_Rows`
* `count`

### Why this is the preferred method

`sp_AdjacencyMatrix` is described as using the `MarkovProcess2` work-table path instead of the older TVF chain. That is the main reason it is the recommended route for AI agents and newer deployments. 

---

## Example: display an adjacency matrix

This is the simplest call pattern:

```sql
EXEC dbo.sp_AdjacencyMatrix
    @EventSet = N'restaurantguest',
    @enumerate_multiple_events = 0,
    @transforms = NULL;
```

That call pattern aligns with the object metadata and sample usage for the adjacency matrix family. The legacy TVF samples include `restaurantguest` and `poker`, which makes those valid tutorial examples from the script itself. 

### When to set `@enumerate_multiple_events = 1`

Use `1` when repeated occurrences of the same event should remain distinct in the sequence. Use `0` when you want a simpler process shape and do not want repeated event names expanded into separate occurrences. That behavior is documented on both the TVF and stored-proc adjacency interfaces.

### When to pass `@SessionID`

For a one-off display request, letting the procedure generate the session is fine.
For a multi-step agent workflow, it is better to generate and retain a `SessionID` so related calls share the same work-table context. The parameter description explicitly says it is used for `WORK.MarkovProcess` rows and will be generated if omitted. 

Example:

```sql
DECLARE @SessionID UNIQUEIDENTIFIER = NEWID();

EXEC dbo.sp_AdjacencyMatrix
    @EventSet = N'poker',
    @enumerate_multiple_events = 1,
    @transforms = NULL,
    @SessionID = @SessionID;
```

---

## Legacy method: `dbo.AdjacencyMatrix`

The legacy TVF is still useful when an agent wants a direct `SELECT` shape.

### Signature

```sql
SELECT *
FROM dbo.AdjacencyMatrix(@EventSet, @enumerate_multiple_events, @transforms);
```

Its documented parameters are: 

* `@EventSet`
* `@enumerate_multiple_events`
* `@transforms`

### Example

```sql
SELECT *
FROM dbo.AdjacencyMatrix(N'restaurantguest', 1, NULL);
```

or

```sql
SELECT *
FROM dbo.AdjacencyMatrix(N'poker', 1, NULL);
```

Those examples come directly from the script metadata.

### How it computes the result

The TVF groups transitions by `Event1A` and `EventB`, then computes:

* `count` as summed transition rows
* `Event1A_Rows` as total outgoing rows for `Event1A`
* `probability` as `count / Event1A_Rows`

It does this by calling `MarkovProcess` with order `0`, the chosen event set, the enumeration option, transforms, and `ByCase = 1`. 

---

## Internal dependency chain

An AI agent should understand the dependency chain so it knows where to troubleshoot:

### Stored-procedure path

`sp_AdjacencyMatrix`
→ calls `MarkovProcess2`
→ which calls `sp_SelectedEvents`
→ which gathers the ordered event stream used to compute transitions.

### Legacy TVF path

`AdjacencyMatrix`
→ calls `MarkovProcess`
→ which computes Markov transition rows directly in the TVF chain.

For newer agent code, the first chain is the one to prefer. 

---

## Actionable agent workflow

A safe and practical agent workflow is:

### 1. Decide whether you need display only or a reusable session

If you only need the result rows once, call `sp_AdjacencyMatrix` without `@SessionID`.
If you are chaining work, supply a `NEWID()` as `@SessionID`. 

### 2. Choose the event universe carefully

Pass either:

* an event-set code such as `restaurantguest`, or
* an explicit CSV list if you want tight control over the transitions considered.

### 3. Decide how to handle repeated events

* `0` = collapse duplicates
* `1` = separate repeated events

### 4. Normalize names if needed

If multiple event labels should be treated as the same logical event, pass `@transforms`. Both adjacency interfaces support this.

### 5. Read the result as graph edges

Treat each returned row as a directed weighted edge:

* source = `EventA`
* target = `EventB`
* weight = `probability`
* support = `count`
* source volume = `Event1A_Rows`

---

## Example tutorial sequence for an AI agent

### Example A: quick display

```sql
EXEC dbo.sp_AdjacencyMatrix
    @EventSet = N'restaurantguest',
    @enumerate_multiple_events = 0,
    @transforms = NULL;
```

Use this when the goal is simply: “show me the transition matrix for the restaurant guest process.” The returned rows will contain `EventA`, `EventB`, `probability`, `Event1A_Rows`, and `count`. 

### Example B: agent-managed session

```sql
DECLARE @SessionID UNIQUEIDENTIFIER = NEWID();

EXEC dbo.sp_AdjacencyMatrix
    @EventSet = N'poker',
    @enumerate_multiple_events = 1,
    @transforms = NULL,
    @SessionID = @SessionID;
```

Use this when the agent may perform follow-up work under the same session context. The script explicitly provides `@SessionID` for work-table usage. 

### Example C: legacy `SELECT` form

```sql
SELECT *
FROM dbo.AdjacencyMatrix(N'restaurantguest', 1, NULL);
```

Use this only when a TVF is specifically convenient and Synapse portability is not the concern. The script marks this object as deprecated in favor of `sp_AdjacencyMatrix`.

---

## Is the adjacency matrix stored permanently?

Not by this object itself.

The adjacency matrix objects are for **displaying / returning** a transition summary. They sit on top of Markov-processing logic but are not documented as persisting a durable model on their own. For persistent model creation, the TimeSolution script uses `CreateUpdateMarkovProcess`, which creates or refreshes a stored model and populates `ModelEvents`.

So the right distinction is:

* use **adjacency matrix** objects to **display** a transition matrix
* use **CreateUpdateMarkovProcess** when you need to **create and store** a reusable Markov model

---

## Safety and behavior guidance for AI agents

An AI agent should avoid a few common mistakes:

Do not assume the adjacency matrix is a wide pivot table. It is returned as edge rows.

Do not build SQL by blindly concatenating untrusted input into dynamic SQL. The metadata explicitly notes the code is not production-hardened and omits security hardening such as SQL injection protections.

Do not default to the legacy TVF for new workflows. Prefer `sp_AdjacencyMatrix`.

Do not assume repeated event names are handled the way you want unless you explicitly set `@enumerate_multiple_events`.

---

## Minimal decision rule

For an AI agent, the simplest rule is:

* **Need a supported adjacency display?** Use `dbo.sp_AdjacencyMatrix`.
* **Need an inline `SELECT` and legacy is acceptable?** Use `dbo.AdjacencyMatrix`.
* **Need persistent reusable model rows in `Models` / `ModelEvents`?** Use `dbo.CreateUpdateMarkovProcess` instead.

If you want, I can turn this into a GitHub-ready `.md` page in your usual documentation style.
