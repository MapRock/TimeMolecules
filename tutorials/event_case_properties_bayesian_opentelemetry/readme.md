
# Tutorial: Event & Case Properties – Discovering Hidden States in Time Molecules



## Conceptual Foundation – How Time Molecules Discovers Hidden States

Events in real-world systems are never just labels. Every event arrives with a rich **payload of properties**. This is now standard in modern event processing — OpenTelemetry, CloudEvents, and telemetry standards all treat the payload as a core part of the event.

In Time Molecules these payloads are explicitly modeled as four distinct property types on every event:

- **ActualProperties**
- **IntendedProperties**
- **ExpectedProperties**
- **AggregationProperties**

Plus a parallel set of **CaseProperties** that describe the entire process instance.

These properties *are* the hidden states of the process. They let us deduce or infer context, conditions, and causal factors that the event name or sequence alone cannot reveal. Hidden states may also live in seemingly separate but highly influential parallel processes (weather, system load, agent state, market conditions, etc.).

Because of this, effective process intelligence goes beyond simple first-order Markov models. It requires **Bayesian and conditional probability reasoning** — understanding not just “what usually follows what,” but “what is likely to follow *given* these specific properties and context.” This hybrid Markov + Bayesian approach is a central theme of Chapter 9 of the Time Molecules book.

Event and case properties are therefore the primary mechanism for discovering hidden states in Time Molecules.

## 1. How Properties Are Stored and Explored

```sql
-- All parsed event properties (with source context)
SELECT TOP 100 * 
FROM dbo.vwEventPropertiesParsed 
ORDER BY EventDate DESC;
```

```sql
-- All parsed case properties (with source context)
SELECT TOP 100 * 
FROM dbo.vwCasePropertiesParsed 
ORDER BY CaseID;
```

These views surface the four property types plus rich source metadata.

## 2. Sources + SourceColumns – The Ingestion Engine

Raw payloads are mapped to standardized properties through the official mechanism:

```sql
-- All registered sources
SELECT * FROM dbo.Sources ORDER BY SourceName;

-- Raw columns → standardized properties (the mapping layer)
SELECT 
    sc.SourceName,
    sc.ColumnName,
    sc.PropertyName,
    sc.Description,
    sc.IRI,
    sc.DataType,
    s.DefaultTableName
FROM dbo.vwSourceColumnsFull sc
ORDER BY sc.SourceName, sc.ColumnName;
```

New OpenTelemetry streams, IoT feeds, AI agent logs, or any event source are registered once here. The ETL then automatically parses the payloads into the four property types.

## 3. Properties → Bayesian Probabilities

The stored procedure `CreateUpdateBayesianProbabilities` uses event and case properties as the hidden-state filters:

```sql
	EXEC dbo.CreateUpdateBayesianProbabilities
		@SeqA = 'arrive,greeted',
		@SeqB = 'intro,order',
		@EventSet = 'restaurantguest',
		@StartDateTime = '19000101',
		@EndDateTime = '20501231',
		@transforms = NULL,
		@CaseFilterProperties = NULL,
		@EventFilterProperties = NULL,
		@GroupType = 'CASEID';
```

These Bayesian probabilities become the probabilistic memory that powers Markov models and cause-and-effect analysis.

## 4. Properties Feed Star Schema and Data Vault

The same event and case properties are the foundation for the dimensional and Data Vault layers:

- **Star Schema** (`tutorials/star_schema/`) – properties become dimensions and facts in `DIM.*` and `FACT.*`
- **Data Vault** (`tutorials/data_vault_connect_time_molecules_to_semantic_layer/`) – properties feed hubs, satellites, and links

This makes the Kyvos semantic layer a natural consumer of the enriched, property-driven structures.

## Hands-on Exercises

```sql
-- 1. Explore the properties that reveal hidden states
SELECT TOP 50 * FROM dbo.vwEventPropertiesParsed ORDER BY EventDate DESC;
SELECT TOP 50 * FROM dbo.vwCasePropertiesParsed ORDER BY CaseID;

-- 2. See how sources map to properties
SELECT * FROM dbo.vwSourceColumnsFull ORDER BY SourceName, ColumnName;

-- 3. Run Bayesian reasoning with hidden-state properties
    EXEC dbo.BayesianProbability2
        @SeqA = 'GameState-1',
        @SeqB = 'folds',
        @EventSet = NULL,
        @StartDateTime = '19000101',
        @EndDateTime   = '20501231',
        @transforms    = NULL,
        @CaseFilterProperties  = NULL,
        @EventFilterProperties = NULL,
        @GroupType     = NULL,
        @SessionID     = NULL;
```

### Next Steps

- `[tutorials/property_mdm_iri_rollup/](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/property_mdm_iri_rollup)`
- `[tutorials/kyvos_semantic_layer_as_source](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/kyvos_semantic_layer_as_source)`
