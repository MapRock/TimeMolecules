* Prompt: How do you discover and select the right events to include in an @EventSet for building an accurate Markov model of a specific case type?
* Abstract: Selecting events for an EventSet starts by analyzing which events have historically appeared inside cases of a target case type over a defined time window. This produces a frequency-ranked inventory of every observed event, revealing the actual vocabulary used in that case type.

Core process events — the meaningful business steps that advance the case — typically show high occurrence counts and clear relevance in their descriptions. Noise events such as UI interactions, status updates, logging actions, or administrative tasks can be identified and excluded. The final EventSet is a curated, semantically focused subset containing only the events that truly represent the process flow.

This case-type-driven discovery and curation step ensures the subsequent Markov model captures genuine transition dynamics instead of being polluted by irrelevant activity, resulting in cleaner probabilities and more actionable insights.
* Primary location of source material to analyze (for more information): https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/selecting_events_for_event_set_from_case_types.md
