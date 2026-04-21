
## How to use `dbo.vwCaseTypeEventCounts` to discover candidate event sets

In TimeSolution, **`dbo.vwCaseTypeEventCounts`** is a helper object for exploring which events have historically appeared within each case type. It is useful when an AI agent is trying to propose or refine an **event set** for later Markov modeling.

Unlike a model-building procedure, this object does **not** build a Markov model. Instead, it summarizes the observed events by case type and returns counts of how often each event appears, while filtering rows through the current user's access bitmap. That makes it a good first step when an agent needs to answer questions such as:

- What events are commonly used for CaseType 17?
- Which events seem central to this case type, and which look optional or noisy?
- If I want to create an event set for this case type, what events should I start with?
- Which events might need to be excluded before creating a cleaner Markov model?

---

## What this object is for

Use **`vwCaseTypeEventCounts`** when an agent needs to discover the vocabulary of events associated with a case type before deciding which events to include in an event set.

This is especially useful because a case type may contain:

- core process events that define the main flow,
- support or side-channel events that may still be valid but not central,
- administrative or technical events that may need to be excluded from the event set.

The object helps the agent form an initial candidate list by showing the events that have actually occurred for visible cases of that type.

---

## Important note on date restriction

In practice, event-set discovery often needs to be restricted to a time window in order to reduce the search space and better reflect the period of interest.

Examples:

- only events seen in the last 90 days,
- only events seen during 2025,
- only events seen after a workflow redesign,
- only events seen before a known policy change.

That date filtering should be pushed down to the `EventsFact` table using:

- `EventsFact.StartDateTime`
- `EventsFact.EndDateTime`

For that reason, an **inline table-valued function** is usually better than a plain view, because it can accept `@StartDateTime` and `@EndDateTime` and apply them directly in the underlying query.

---

## What it returns

The object returns these columns:

- `CaseTypeID`
- `CaseTypeName`
- `CaseTypeDescription`
- `CaseTypeIRI`
- `Event`
- `EventDescription`
- `Occurrences`

Each row represents one event observed within one case type, along with the number of occurrences in the filtered set of visible events.

So this is not yet a transition model. It is a frequency summary of event usage by case type.

---

## What the query actually does

### 1. Gets the current user's access bitmap

The query retrieves the current user's bitmap through:

```sql
dbo.UserAccessBitmap()
````

This allows the result to honor row-level visibility rules.

### 2. Reads events and joins case metadata

The query reads from:

* `dbo.EventsFact`
* `dbo.DimEvents`
* `dbo.Cases`
* `dbo.CaseTypes`

This lets it connect each event occurrence to:

* its case,
* the case's case type,
* and the descriptive metadata for both the case type and the event.

### 3. Restricts the search space by time window

When implemented as a parameterized inline table-valued function, the query should filter `EventsFact` by `StartDateTime` and `EndDateTime` before aggregation.

This matters because the time window can significantly affect which events appear to belong to a case type. It also reduces the amount of data that must be scanned.

### 4. Applies access filtering

The query includes rows where either:

* `c.AccessBitmap = -1`, meaning unrestricted, or
* the current user's access bitmap overlaps the case access bitmap.

So the result set is already filtered to what the current caller is allowed to see.

### 5. Groups by case type and event

The query groups by case type and event and returns:

```sql
COUNT(*) AS Occurrences
```

This gives a simple event-frequency profile for each case type within the selected time range.

---

## How an AI agent should use this object

### Primary use

An agent should use this object as a **discovery step** before building or recommending an event set.

A practical workflow is:

1. Pick a target `CaseTypeID` or `CaseTypeName`.
2. Pick a relevant `StartDateTime` and `EndDateTime`.
3. Query the object for that case type and date range.
4. Review the returned events and their occurrence counts.
5. Separate likely core events from likely noise.
6. Propose an event set containing the events that should participate in the next modeling step.

### Important interpretation rule

High occurrence count does **not** automatically mean an event belongs in the final event set.

Some high-frequency events may still be poor choices if they are:

* overly generic,
* technical logging artifacts,
* repeated administrative touches,
* or not meaningful for the process story the model is meant to capture.

Likewise, a lower-frequency event may still be important if it is structurally meaningful in the process.

So the object is best used to form a **candidate event list**, not to blindly finalize an event set.

---

## Recommended implementation pattern

If date restriction matters, prefer an inline table-valued function such as:

### `dbo.CaseTypeEventCounts`

Parameters:

* `@StartDateTime`
* `@EndDateTime`

This allows the date predicate to be pushed directly into the `EventsFact` scan.

A plain view can still be useful for broad exploration, but for agent workflows that should minimize search space, the parameterized inline TVF is the better choice.

---

## Sample query: inspect one case type within a date range

```sql
SELECT
    CaseTypeID,
    CaseTypeName,
    Event,
    EventDescription,
    Occurrences
FROM dbo.CaseTypeEventCounts('2025-01-01', '2025-12-31')
WHERE CaseTypeID = 17
ORDER BY Occurrences DESC, Event;
```

This helps an agent see which events are most common within a particular case type during the selected period.

---

## Sample query: inspect by case type name within a date range

```sql
SELECT
    CaseTypeID,
    CaseTypeName,
    Event,
    EventDescription,
    Occurrences
FROM dbo.CaseTypeEventCounts('2025-01-01', '2025-12-31')
WHERE CaseTypeName = 'Emergency Room Laboratory workflow'
ORDER BY Occurrences DESC, Event;
```

This is helpful when the agent starts from the business meaning rather than the numeric ID.

---

## How to turn the result into a candidate event set

A practical agent workflow is:

### Step 1: get the event inventory for a case type in the relevant period

```sql
SELECT
    Event,
    EventDescription,
    Occurrences
FROM dbo.CaseTypeEventCounts('2025-01-01', '2025-12-31')
WHERE CaseTypeID = 17
ORDER BY Occurrences DESC, Event;
```

### Step 2: identify likely core process events

The agent should prefer events that appear to represent meaningful business steps, such as:

* intake,
* order placed,
* item prepared,
* result produced,
* handoff completed,
* discharge,
* payment,
* departure.

### Step 3: identify likely exclusions

The agent should consider excluding events that look like:

* generic status refreshes,
* UI-only clicks,
* internal logging artifacts,
* repeated notifications,
* low-value audit events,
* events outside the intended process scope.

### Step 4: propose an event set

The final event set is the subset of events chosen for the intended model. The object helps discover the candidates, but the event set reflects a modeling decision.

---

## Example interpretation

Suppose the object returns these event names for a case type:

* `arrive`
* `triage_started`
* `triage_completed`
* `lab_ordered`
* `lab_resulted`
* `status_refreshed`
* `screen_opened`
* `depart`

An agent may conclude that the likely candidate event set is:

* `arrive`
* `triage_started`
* `triage_completed`
* `lab_ordered`
* `lab_resulted`
* `depart`

while leaving out:

* `status_refreshed`
* `screen_opened`

because those appear more like support or UI events than core process events.

---

## Practical guidance for agents

An agent should follow these rules:

* **Use this object early.** It is a discovery tool for finding the event vocabulary of a case type.
* **Prefer a date-restricted query.** This reduces search space and keeps the candidate events tied to the relevant period.
* **Do not treat it as a Markov model.** It reports event frequencies, not transitions.
* **Do not assume the highest-count events are automatically best.** Frequency helps, but semantic relevance still matters.
* **Use event descriptions when available.** They often help distinguish business events from technical or administrative ones.
* **Treat the result as candidate input to an event set.** The final event set may intentionally leave out some visible events.
* **Filter to the target case type whenever possible.** This keeps the event inventory aligned to the intended process family.

---

## Minimal tutorial summary

To use this object for event-set discovery in TimeSolution:

1. Choose the target case type.
2. Choose a relevant date range.
3. Query the case type event counts within that date range.
4. Review the returned events and their occurrence counts.
5. Separate likely core process events from likely noise or support events.
6. Propose an event set for downstream modeling.

For broad exploration, a view may be acceptable. For AI-agent workflows that should reduce the search space efficiently, a parameterized inline TVF is usually the better implementation.


