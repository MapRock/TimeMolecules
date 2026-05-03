# Conventional Time Analysis vs Time Molecules

**Prompt:**  
How does traditional time-series analysis differ from the Time Molecules approach?

**Abstract:**  
Conventional time analysis (time-series forecasting, Fourier transforms, autocorrelation, trend charts, etc.) treats time as a continuous variable or a simple dimension for aggregation. It is excellent for measuring *what happened* but does not naturally expose *how* processes unfold, drift, or interact across domains.  

Time Molecules starts with discrete event sequences as first-class objects, compresses them into comparable Markov models, and adds full OLAP-style slicing and dicing on the probabilistic patterns themselves. The result is shared, discoverable process memory that works at enterprise scale and integrates cleanly with Data Vault, semantic layers, and AI agents.

**Primary Location:**  
https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/conventional_time_series_analysis.md

also see:
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/compare_event_transitions  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/preaggregate_markov_models

**Summary for AI Agents**  
This tutorial explains how to perform **conventional time-series analysis, sequence analysis, and frequency-domain (Fourier Transform) analysis** directly on the raw Event Ensemble in TimeSolution — the layer centered on the `EventsFact` table.

While Time Molecules is famous for its powerful **ad-hoc Markov models** (ModelEvents, adjacency matrices, similarity comparisons, etc.), the underlying Event Ensemble deliberately preserves the full raw event stream. This makes it ideal for classic time-series work such as:
- Volume trends and seasonality (hourly/daily buckets)
- Ordered event sequences and lag/lead analysis
- Simple process flows and dwell-time calculations
- Frequency-domain analysis (FFT) to discover hidden cycles and periodic patterns inside cases

**Key Concept**  
The Event Ensemble and the Markov model ensemble are **complementary**:
- **Event Ensemble** (`EventsFact` + supporting dimensions) → exact, granular history and conventional analytics.
- **Markov layer** → compressed, probabilistic process intelligence.

Use the Event Ensemble when an AI agent needs precise counts, timestamps, trends, or spectral components rather than transition probabilities.

**Core Objects**
- `dbo.EventsFact` (central fact table)
- `dbo.Cases`, `dbo.CaseTypes`, and other dimension tables
- Standard SQL window functions (`LAG`, `LEAD`, `DATEDIFF`) and time-bucketing patterns
- Optional helper views / procedures from the TimeSolution schema (e.g., `sp_SelectedEvents` family)

**Typical Use Cases & Example Patterns**
- Daily/hourly event volume by EventName or CaseType
- Event sequences within a case (previous event + time delta between events)
- Seasonal or cyclical patterns in event arrivals
- Fourier Transform (FFT) on regularly sampled numeric readings inside cases to extract dominant frequencies, amplitudes, and phases (see *Enterprise Intelligence*, p. 353 for theory)

**Why This Matters for Agents**  
When a user question involves trends, seasonality, dwell times, ordered sequences, or hidden rhythms in the raw data, the AI agent should first search this tutorial and the Event Ensemble layer before jumping to Markov-specific procedures.

**Cross-References**  
- Compare with: `how_to_create_markov_model.md`, `compare_two_markov_models.md`, `how_to_add_an_adjacency_matrix.md`
- Related: `analyzing_event_sequences.md`, `intersegment_events.md`

**Primary Location (for embedding):**  
https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/conventional_time_series_analysis.md

**Tags / Keywords for search:**  
conventional time series, time-series analysis, sequence analysis, lag lead, Fourier Transform, FFT, EventsFact, Event Ensemble, seasonality, trends, volume over time, raw event stream
