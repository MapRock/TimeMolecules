# `sp_SelectedEvents` and the Shift Toward MPP-Friendly Time Molecules

One of the important refactors in the current TimeSolution codebase is the move away from the old `dbo.SelectedEvents` table-valued function and toward the stored procedure `dbo.sp_SelectedEvents`.

This change was not made because it is automatically faster on ordinary SQL Server. In many cases, it will not be. It was made because it moves TimeSolution closer to a form that can survive in a very large-scale environment such as Snowflake, Azure Synapse, or other massively parallel processing (MPP) platforms.

For readers of *Time Molecules*, this is an architectural step toward scale-out deployment.

---

## Why `SelectedEvents` matters so much

A large part of TimeSolution begins with the same problem:

> Given a set of events, a time window, transforms, and optional property filters, which exact events should participate in the calculation?

That question shows up all over the system:

- building Markov models
- drilling through to events behind a model
- finding sequences
- calculating probabilities
- comparing process behavior across slices

So there has always been a central object that does this event selection work.

Originally, that was the table-valued function `dbo.SelectedEvents`.

Now, in the refactored design, that role is handled by:

- `dbo.sp_SelectedEvents`

---

## What `sp_SelectedEvents` does

At a high level, `sp_SelectedEvents` takes the request for a model-ready event set and turns it into a session-scoped working table that other procedures can read.

It is responsible for resolving and staging things such as:

- the requested event set
- default model parameters
- start and end date/time
- transforms that rename or normalize events
- case-level property filters
- event-level property filters
- metric handling
- sequence enumeration behavior

Its output is not just a logical stream of rows. Instead, it materializes rows into a work table in the `WORK` schema, keyed by a `SessionID`.

That means the process becomes more like this:

1. A caller generates a `SessionID`
2. The caller executes `sp_SelectedEvents`
3. `sp_SelectedEvents` writes the selected event rows into `WORK.SelectedEvents`
4. The downstream procedure reads only rows for that session
5. The downstream procedure finishes and removes its session rows

This is a very different shape from a pure TVF-based design.

---

## The basic flow

Conceptually, `sp_SelectedEvents` performs work like this:

### 1. Resolve defaults

It uses helper logic such as default model parameter handling so that missing values like date ranges or metric settings are filled in consistently.

### 2. Parse the event set

If the caller passes an event set code or list of events, the procedure expands that into a usable event list.

### 3. Parse transforms

If transforms are supplied, event names can be normalized or remapped before analysis.

### 4. Parse property filters

Case properties and event properties can be filtered by structured rules instead of being hard-coded into every consuming object.

### 5. Materialize the selected events

The filtered and normalized event rows are written into `WORK.SelectedEvents` with a `SessionID`.

### 6. Support downstream procedures

Other procedures then read from `WORK.SelectedEvents` for their own logic.

This makes `sp_SelectedEvents` the central staging procedure for much of the current TimeSolution workflow.

---

## Why this may be slower on regular SQL Server

This change is not free.

On ordinary SQL Server, especially on a single-box SMP system, the old TVF style could sometimes be faster because it avoided some explicit staging. The optimizer might be able to inline or at least reason through a large query more directly.

With the new design, there is often extra work:

- writing selected rows into `WORK.SelectedEvents`
- reading those rows back out
- deleting them afterward by `SessionID`

That means:

- more I/O
- more logging
- more worktable churn
- more dependence on intermediate materialization

So if someone runs the same logic on a traditional SQL Server instance and asks, “Why is this not faster?”, the honest answer is:

> Because this refactor was not primarily about making one-box SQL Server faster. It was about making the system more deployable at very large scale.

That distinction matters.

---

## Why this shape is friendlier to MPP

Massively parallel systems often do better when work is broken into explicit stages.

A deeply nested table-valued function can be elegant in SQL Server, but it can also be difficult for a distributed engine to optimize well. In contrast, a staged pattern says:

- first, determine the event rows
- then, materialize them
- then, let downstream objects operate on that staged set

That is closer to how large-scale distributed systems tend to think.

### Benefits of the staged approach

#### 1. Clear materialization boundary

`sp_SelectedEvents` creates an explicit boundary between “event selection” and “downstream analytics.”

That is often easier to scale than having every object recompute complex filtering logic from scratch.

#### 2. Reuse across many downstream procedures

Many TimeSolution objects need the same selected event set. Materializing once makes the dependency explicit.

#### 3. Better fit for distributed execution

MPP systems typically prefer work to be expressed as stages with concrete intermediate rowsets rather than as deeply nested logic trees.

#### 4. Easier future refactoring

Once event selection is isolated into one procedure, the internals can later be reworked for a specific platform without rewriting every consumer.

That is important. A bridge architecture does not need to be the final architecture. It needs to be the right shape for the next move.

---

## Why the `WORK` schema exists in this pattern

The `WORK` schema is being used as a session-scoped staging area.

This gives TimeSolution a place to persist intermediate rowsets that multiple stored procedures can share during a request.

The key pattern is:

- rows are tagged with `SessionID`
- a caller only reads its own session rows
- rows are cleaned up after use

This is not merely a convenience. It is part of moving from a purely compositional SQL style to an orchestration-oriented SQL style.

That said, on a large MPP platform, this pattern may itself evolve.

For example, future versions might use:

- transient or temporary distributed tables
- platform-specific staging tables
- partitioned session work areas
- batch cleanup or time-to-live cleanup instead of immediate delete
- orchestration outside the database for some stages

So the current `WORK` pattern should be seen as an intermediate architecture, not necessarily the final one.

---

## Objects that typically depend on `sp_SelectedEvents`

A number of TimeSolution procedures follow the same pattern:

1. generate a `SessionID`
2. call `sp_SelectedEvents`
3. read the staged rows from `WORK.SelectedEvents`
4. continue with their specific logic

Examples include procedures for:

- model drillthrough
- sequence discovery
- event sequence analysis
- Markov-oriented aggregations
- probability-oriented analysis

This is exactly why centralizing the selected-event logic matters. Once event selection becomes stable and reusable, other objects can focus on their own purpose rather than each reinventing event filtering.

---

## Why this matters for *Time Molecules*

Readers of *Time Molecules* will recognize that the system is not mainly about storing raw events. It is about turning raw events into reusable process intelligence.

That requires a recurring pattern:

- identify relevant events
- shape them into ordered sequences
- aggregate them into process structures
- compare those structures across slices, properties, and dimensions

`sp_SelectedEvents` sits near the beginning of that pipeline.

If it can be made portable and scalable, the rest of TimeSolution has a much better chance of scaling as well.

In that sense, this refactor is not a cosmetic code change. It is part of preparing the conceptual engine of Time Molecules for bigger platforms.

---

## What this refactor does **not** mean

It does **not** mean:

- that TimeSolution is already fully optimized for Snowflake or Synapse
- that writing to the `WORK` schema is always ideal
- that SQL Server performance will always improve
- that all scale problems are now solved

It means something narrower and more important:

> The codebase is being reshaped from a TVF-heavy pattern into a staged, procedure-driven pattern that is much more plausible for future MPP deployment.

That is the real significance.

---

## A practical way to think about it

A good way to think of the old and new patterns is this:

### Old style
“Whenever you need selected events, recompute them as part of the larger expression.”

### New style
“First create the selected event set for this session, then let downstream procedures operate on it.”

The first style can be elegant and sometimes fast on a traditional SQL Server.

The second style is often clunkier on a single machine, but it is much closer to how a scalable distributed analytics system is likely to be built.

---

## Bottom line

`sp_SelectedEvents` is a strategic refactor.

It may add overhead on regular SQL Server because it introduces explicit staging and cleanup work. But it also moves TimeSolution in a direction that is far more realistic for large-scale deployment.

For Time Molecules, that matters.

The long-term goal is not merely to run a clever table-valued function on a development SQL Server. The goal is to bring process-oriented intelligence into environments large enough to matter across real enterprises.

`sp_SelectedEvents` is one step toward that.
