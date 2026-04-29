# Data Vault Bridge – Connecting TimeSolution Event Ensemble to Data Mesh and Traditional BI

**Prompt:**  
How does TimeSolution integrate with an existing Data Vault and Data Mesh architecture?

**Abstract:**  
The Data Vault pattern serves as the enterprise integration layer (bridge) between the TimeSolution Event Ensemble (`EventsFact`, parsed properties, cases) and both traditional BI systems (star schemas) and a full Data Mesh.  

Raw events land immediately in the Raw Data Vault (Hubs/Links from `EventsFact` + metric properties). Business Vault applies governed transformations. From there, star-schema data marts and/or a modern universal semantic layer (Kyvos) are extracted. This allows the same event data to power Time Molecules Markov discovery **and** conventional BI reporting without duplication.  

At the customer-facing level, users see only the governed Kyvos semantic layer.

**Primary location of source material to analyze (for more information):**  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/data_vault_connect_time_molecules_to_semantic_layer  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/star_schema  
https://github.com/MapRock/TimeMolecules/tree/main/tutorials/kyvos_semantic_layer_as_source  
https://eugeneasahara.com/2022/01/02/data-vault-data-mesh/
