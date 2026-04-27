**Prompt:**  
How do I use the Kyvos Semantic Layer as the primary property source in Time Molecules so that Markov models and cases can be enriched and sliced with consistent, governed enterprise dimensions and measures?

**Abstract:**  
Time Molecules separates the *time-side* (event sequences and their Markov abstractions) from the *thing-side* (facts, dimensions, hierarchies, and measures). The Kyvos Semantic Layer is the recommended primary property source for the thing-side.  

Once registered with `dbo.InsertSource` (using `SourceType = 'KYVOS_SEMANTIC_LAYER'` and `IsPropertySource = 1`) and its columns/measures registered with `dbo.InsertSourceColumns`, every case, event, and Markov model can automatically pull governed business dimensions, hierarchies, and calculated metrics directly from Kyvos. This enables consistent slicing and dicing of Markov models by any Kyvos-defined dimension (customer segment, product hierarchy, location, department, etc.) exactly as you would slice an OLAP cube, while preserving full traceability back to the underlying event sequences.  

The result is true process-aware intelligence: Kyvos supplies the authoritative, governed “thing-centric” context; Time Molecules supplies the living, interacting “time-centric” process memory. Together they create a unified, enterprise-scale foundation for discovery, comparison, and reasoning over both facts and processes.

**Primary location of source material to analyze (for more information):** https://github.com/MapRock/TimeMolecules/tree/main/tutorials/kyvos_semantic_layer_as_source
