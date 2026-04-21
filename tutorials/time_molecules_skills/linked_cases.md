
# How to discover and analyze linked cases in TimeSolution

In TimeSolution (the SQL Server implementation of Time-Molecules), **linking cases** enables AI agents to uncover relationships between cases across different processes or case types, even when the data originates from separate systems. This includes:

- Identifying linked case types through shared natural keys (e.g., a `VisitID` passed from an Emergency Room process to an MRI process).
- Detecting intersections or overlaps between cases involving the same or related entities (individuals, locations, etc.).
- Using semantic similarity of property/column names to support fuzzy or indirect linkages when exact matches are absent.

These capabilities support process mining, cross-system analytics, and composite case analysis without requiring explicit foreign keys in every event stream. The approach combines exact matching on property values, semantic analysis via LLM-assisted column pairing, and proximity detection.

## What this is for

Use linking case features when an AI agent needs to answer questions such as:

- Are there hidden relationships between an ER check-in case and a downstream lab/MRI case?
- Do two cases (possibly involving different individuals) share contextual overlaps, such as the same location or timing patterns?
- Which case types in the database are likely connected through forwarded business metadata?

Results help build richer process views, support knowledge graph construction, or feed higher-level analytics like Markov model ensembles across subprocesses.

## Prerequisites

Before using link-cases functionality, an AI agent should ensure:

1. The **TimeSolution database** is installed and populated with event data, cases, case properties, and sources. See the installation guide for details.
2. Relevant case types and events exist with populated `CaseProperties` or event-level properties that may contain shared natural keys (e.g., `VisitID`, `RequestorCaseID`).
3. For semantic similarity support: Run or review the Python script `source_column_semantic_similarity.py` (using the prompt in `llm_prompt_similarity_score_event_properties.txt`) to generate and import `similar_column_pairs.csv` via `import_similar_column_pairs_csv.sql`. This populates the `dbo.SimilarSourceColumnPairs` table.
4. The agent has execute permissions on relevant stored procedures and read access to profiling tools like `dbo.sp_CasePropertyProfiling`.
5. Data follows best practices: Forward natural keys across process boundaries where possible to strengthen analytical connectivity.

**Security note**: Queries operate only on existing database objects. Avoid broad or unfiltered scans on large production datasets without appropriate indexing and time bounding. Do not use these tools for real-time surveillance or any purpose that could violate privacy regulations.

## Key objects and scripts

### 1. `dbo.sp_CasePropertyProfiling`
Helps explore available case-level properties and their frequency before attempting linkages.

### 2. `find_related_case_types.sql`
SQL script that identifies potential linkages between case types by matching property values that appear as natural keys across different case types.

### 3. Semantic similarity support
- `similar_column_pairs.csv` + `import_similar_column_pairs_csv.sql`: Loads LLM-determined similar column pairs (e.g., "VisitID" ≈ "RequestorCaseID") into `dbo.SimilarSourceColumnPairs`.
- Adjust descriptions in the `SourceColumns` table if semantic matches need refinement.

### 4. `dbo.sp_CompareEventProximities`
Stored procedure for comparing event proximities between two filtered sets of cases. Useful for detecting shared context (e.g., same GPS coordinates or other property values indicating physical or operational overlap).

#### Parameters
- `@CaseFilterProperties1` NVARCHAR(MAX) — JSON string of property filters for the first case set (e.g., `'{"LocationID":1,"EmployeeID":1}'`).
- `@CaseFilterProperties2` NVARCHAR(MAX) — JSON string of property filters for the second case set.
- `@StartDateTime` DATETIME = NULL — Optional lower time bound.
- `@EndDateTime` DATETIME = NULL — Optional upper time bound.

The procedure detects shared property values across the filtered events and returns proximity indicators.

## Actionable examples

### Example 1: Profile case properties (exploration step)
```sql
EXEC dbo.sp_CasePropertyProfiling;
```
Review output to identify properties that may serve as linking keys (high-frequency natural keys like VisitID or RequestorCaseID).

### Example 2: Find related case types
Execute the script `find_related_case_types.sql` (or its core query logic). It scans for matching property values across case types and produces linkage statistics. Example output might show connections between "ER Case Management" and lab/MRI workflows via shared `VisitID` values.

### Example 3: Compare event proximities between case sets
```sql
EXEC [dbo].[sp_CompareEventProximities]
    @CaseFilterProperties1 = '{"LocationID":1,"EmployeeID":1}',
    @CaseFilterProperties2 = '{"LocationID":1,"EmployeeID":4}',
    @StartDateTime = NULL,
    @EndDateTime = NULL;
```
This call compares events from two employee-location combinations and surfaces any shared property values (e.g., identical coordinates or identifiers) that indicate proximity or intersection.

For semantic-enhanced linkage, ensure `SimilarSourceColumnPairs` is populated first, then incorporate those pairs into custom queries that join on either exact matches or semantically similar columns.

## How the procedures work (high-level)

- **Exact linking** relies on property values that match exactly across cases (e.g., the same `VisitID` string appearing in both ER and MRI events).
- **Semantic support** uses pre-computed column similarities to expand possible join paths without manual hard-coding.
- **Proximity analysis** scans for overlapping property values within time windows, supporting discovery of unintended or emergent relationships.

These mechanisms are idempotent where possible and designed for analytical rather than transactional workloads.

## Practical guidance for AI agents

- **Start with profiling**: Always run `sp_CasePropertyProfiling` or review `SourceColumns` descriptions before writing linkage queries.
- **Combine techniques**: Use exact key matching for strong signals; layer semantic similarity for exploratory discovery; apply proximity checks for contextual validation.
- **Time bounding**: Supply `@StartDateTime` / `@EndDateTime` where possible to keep queries performant and focused.
- **Interpret results responsibly**: Linkages indicate potential relationships based on data patterns. Validate findings against business context before acting on them. Do not assume causality from correlation alone.
- **Extend safely**: For custom workflows, build on existing objects rather than modifying core tables directly. Use views or parameterized queries to maintain security and reproducibility.
- **Best practice reminder**: Well-designed event systems that forward caller process identifiers (natural keys) across boundaries yield the strongest linkage results.

## Related resources
- [Linking Subprocesses with Case Properties](https://github.com/MapRock/TimeMolecules/blob/main/docs/subprocess_case_linking.md)
- Time-Molecules book concepts on composite cases and event correlation.
- The `book_code/sql` directory for additional pattern examples.

This functionality strengthens TimeSolution's ability to treat processes as interconnected "molecules," enabling agents to reason across system boundaries while respecting the underlying event data model.
