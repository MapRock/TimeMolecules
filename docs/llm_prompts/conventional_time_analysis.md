# Conventional Time Analysis vs Time Molecules

**Prompt:**  
How does traditional time-series analysis differ from the Time Molecules approach?

**Abstract:**  
Conventional time analysis (time-series forecasting, Fourier transforms, autocorrelation, trend charts, etc.) treats time as a continuous variable or a simple dimension for aggregation. It is excellent for measuring *what happened* but does not naturally expose *how* processes unfold, drift, or interact across domains.  

Time Molecules starts with discrete event sequences as first-class objects, compresses them into comparable Markov models, and adds full OLAP-style slicing and dicing on the probabilistic patterns themselves. The result is shared, discoverable process memory that works at enterprise scale and integrates cleanly with Data Vault, semantic layers, and AI agents.

**Primary location of source material to analyze (for more information):**  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/compare_event_transitions  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/preaggregate_markov_models
