

# Compare Event Proximities

**Tutorial: Discovering hidden process relationships by finding where events “bump into each other”**

## Why This Matters

In real-world processes, completely different workflows often collide in space and time.  
A delivery driver stops for lunch at the same restaurant where a commuter grabs coffee.  
A sales call and a support ticket happen on the same street corner within minutes.  

These **event proximities** are powerful clues that the underlying processes might be related — even when they belong to different CaseSets.  

This tutorial shows you how to surface those collisions automatically and turn them into actionable case links.

> This capability is also a practical implementation of **System 0** — the Default Mode Network of AGI (see [Eugene Asahara’s post](https://eugeneasahara.com/2026/01/08/system-0-the-default-mode-network-of-agi/)).  
> Just like the human brain’s background associative thinking, this code quietly scans for weak but meaningful temporal, spatial, and semantic overlaps across event streams and proposes candidate connections for higher-level reasoning.

## What the Tutorial Does

The Python script `compare_event_proximities.py`:
- Takes two CaseSets (or any two groups of events)
- Compares every pair of events using **two signals**:
  1. **Semantic similarity** — LLM embeddings (via Qdrant) to catch events that “mean” the same thing
  2. **Physical/GPS proximity** — Haversine distance to catch events that literally happened near each other
- Outputs ranked “bumps” (high-proximity pairs) that suggest the two processes may share context, customers, locations, or timing patterns

Sample data in `compare_event_proximities.csv` mixes restaurant visits, commuting patterns, and delivery routes — exactly the kind of messy real-world overlap you see in enterprise event logs.

## Files in This Folder

| File                              | Purpose |
|-----------------------------------|---------|
| `compare_event_proximities.py`    | Main script — runs the comparison and ranking |
| `compare_event_proximities.csv`   | Sample input events (two mixed CaseSets) |
| `compare_event_proximities_results.csv` | Example output showing discovered proximities |
| `shared_llm.py`                   | Shared helper for LLM embedding & Qdrant calls |
| `readme.md`                       | This file |

## How to Run

1. Make sure you have the required packages (`qdrant-client`, `pandas`, `numpy`, `geopy`, etc.).
2. Update `shared_llm.py` with your Qdrant connection (or use the local instance from the main repo).
3. Run:

```bash
python compare_event_proximities.py
```

4. Open `compare_event_proximities_results.csv` to see the ranked event bumps and suggested case links.

## Use Cases

- **Process mining** – automatically discover related but undocumented subprocesses
- **Fraud / anomaly detection** – spot unusual co-occurrences across systems
- **Customer journey mapping** – find where sales, support, and delivery touch the same moments
- **AGI-style associative reasoning** – feed these proximity signals into System 0 background loops for hypothesis generation

This is one of the most “alive” parts of TimeMolecules — it turns raw event data into the kind of intuitive, subconscious pattern recognition that feels almost human.

