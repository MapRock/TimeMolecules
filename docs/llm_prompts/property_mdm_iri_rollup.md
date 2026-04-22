Prompt: How should Time Molecules use property-level MDM, IRIs, and rollup hierarchies to normalize case and event properties without requiring that mapping during event ingestion? 

Abstract: Property-level MDM and IRI rollup provides a steward-curated semantic layer for case and event properties. Instead of forcing master-data mapping during event ingestion, raw property values can be loaded first and then later mapped to mastered values through a separate stewardship process. Those mappings can normalize source-specific values, attach semantic web IRIs, support exact or approximate matching, and organize values into parent-child hierarchies for drill-up and drill-down. This makes property values more useful for cross-source alignment, linked-data integration, and higher-level analysis. Even when a full MDM structure does not yet exist, a property can still be semantically anchored by filling the IRI. Because these mappings stabilize and semantically identify property values, Markov models can eventually be built on mastered property values rather than only on raw source-side values. This is a good example of "Time Molecules as the Time-Side of thing-oriented business intelligence".

Primary location of source material to analyze (for more information): https://github.com/MapRock/TimeMolecules/tree/main/tutorials/property_mdm_iri_rollup




