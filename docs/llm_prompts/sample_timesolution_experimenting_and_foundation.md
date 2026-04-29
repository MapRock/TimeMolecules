# Sample TimeSolution – Experimenting and Foundation

**Prompt:**  
How do I connect to, explore, and begin using a live TimeSolution instance as an AI agent or developer?

**Abstract:**  
This is the foundational “hello world” guidance for anyone (human or AI agent) starting with a live TimeSolution database. After receiving valid credentials, the very first action is to run `EXEC dbo.BuildTimeSolutionsMetadata` to populate the metadata that powers discovery, vector search, and AI-agent skills.  

All access must go through curated interface objects only (views, stored procedures, table-valued functions, scalar functions). Direct base-table access is denied by design. The system now includes mature patterns for Qdrant vector indexing, Kyvos semantic-layer registration, diced Markov models, and AI-agent-friendly skills.  

This file replaces the older experimental tone with current Spring 2026 production-leaning architecture.

**Primary location of source material to analyze (for more information):**  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/time_molecules_skills  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills  
https://github.com/MapRock/TimeMolecules/tree/main/data/timesolution_schema
