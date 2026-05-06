
# Event Ensemble – The Universal Event Foundation for Time Molecules

### Value of the Event Ensemble 

The **Event Ensemble** is the **single source of truth** for all raw events in Time Molecules.

While the **Model Ensemble**  is purpose-built for Markov-style probabilistic reasoning, the **Event Ensemble** is deliberately **general-purpose**. It is designed to be the foundational layer that can feed **any** kind of analysis:

- Markov processes (what you already have)
- Classic time series analysis
- Linear regression & forecasting
- Anomaly detection
- **Time travel** queries
- **Event sourcing** patterns
- Semantic-layer BI (Kyvos, Power BI, Tableau, etc.)

This makes the Event Ensemble extremely powerful — it is the **event-sourced warehouse** at the heart of your system.

### Tables in the Event Ensemble 

These tables store the raw, normalized, and enriched event data:

| Table                        | Purpose |
|-----------------------------|---------|
| `dbo.EventsFact`            | Core fact table — every individual event (the "star" at the center) |
| `dbo.EventSets`             | Logical groupings of events (e.g., "cardiology", "sales", "logistics") |
| `dbo.EventProperties`       | Flexible key-value properties attached to events |
| `dbo.EventPropertiesParsed` | Parsed/typed versions of properties for fast querying |
| `dbo.EventPropertiesMDM`    | Master Data Management version of properties (cleaned, standardized) |
| `dbo.EventPairAnomalies`    | Detected unusual event co-occurrences (spatial/temporal/semantic) |

*Table 1 – Event Ensemble tables.*


![Figure 1 – Event Ensemble as an Event Stadium](https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/event_ensemble/images/event_ensemble_timesolution.png)

*Figure 1 – Event Ensemble as an Event Stadium.*

### Shared / Dimensional Tables (Yellow)

These are the common dimensions used by **both** Event Ensemble and Model Ensemble:

- `dbo.DimTime`
- `dbo.DimDate`
- `dbo.DimEvents`
- `dbo.Sources`
- `dbo.SourceColumns`
- `dbo.Metrics`
- `dbo.SimilarSourceColumnPairs`

### How the Event Ensemble Powers Multiple Use Cases

#### 1. Conventional Time Series Analysis
You can directly query `EventsFact` + `EventProperties` for classic time-series work:

- Aggregate events by time windows (`DimTime`, `DimDate`)
- Compute counts, sums, averages, rolling windows
- Run linear regressions, ARIMA, Prophet, or any ML time-series model

(See the companion tutorial: [conventional_time_series_analysis.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/conventional_time_series_analysis.md))

#### 2. Time Travel (Point-in-Time Queries)
Because every event has a precise timestamp, you can "travel back in time":

```sql
-- What was the state of Case XYZ on 2025-03-15 at 14:30?
SELECT *
FROM dbo.EventsFact e
WHERE e.EventTimeKey <= (SELECT TimeKey FROM dbo.DimTime WHERE FullDateTime = '2025-03-15 14:30:00')
  AND e.CaseKey = @CaseKey
ORDER BY e.EventTimeKey;
```

This is the foundation of **bitemporal** or **as-of** reporting.

#### 3. Event Sourcing
The Event Ensemble follows the **Event Sourcing** pattern:

- Events are **immutable** and **append-only**
- Current state of any case/entity is derived by replaying events in order
- You can rebuild any aggregate, report, or machine-learning feature at any point in history

This gives you perfect auditability and reproducibility — critical for regulated domains (healthcare, finance, manufacturing).

#### 4. Semantic Layer (Kyvos)
The Event Ensemble is **perfect** as a source for a semantic layer:

- `EventsFact` + `EventPropertiesParsed` becomes your fact table
- `DimTime`, `DimDate`, `EventSets`, `Sources` become dimensions
- Business users can create measures like "Average Duration", "Event Count by Type", "Co-occurrence Rate" without writing SQL
- Kyvos (or any modern semantic engine) can sit directly on top of these tables and deliver lightning-fast analytics at scale

You get **one canonical event model** that serves both data scientists (raw SQL / Python) and business analysts (semantic layer).

### Recommended Architecture

```
External Systems
       ↓
  EventsFact + EventProperties   ← Event Ensemble (Green)
       ↓
   ┌────────────────────┐
   │ Semantic Layer     │ ← Kyvos 
   │ (Business-friendly)│
   └────────────────────┘
       ↓
   Time Series / Regression / Forecasting
   Markov Models → Model Ensemble (Red)
   Event Sourcing / Time Travel
```

### Next Steps (You’re Ready)

1. Point your semantic layer (Kyvos) at `dbo.EventsFact` and `dbo.EventPropertiesParsed`
2. Start building time-series models directly against the Event Ensemble (see the conventional time series tutorial)
3. Explore **time travel** queries and **event replay** patterns
4. Use `EventPairAnomalies` as a starting point for cross-process intelligence

The Event Ensemble is now your **universal event platform** — not just for Markov models, but for the entire modern data science and analytics stack.



