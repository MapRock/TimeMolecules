# Data Vault Bridge: Linking TimeSolution Event Ensemble to Traditional BI Systems and Data Mesh

This tutorial shows how the **Data Vault** modeling pattern serves as the enterprise integration layer that seamlessly connects the TimeSolution Event Ensemble (the core of Time Molecules) to traditional BI systems—whether those BI systems are existing star-schema data marts or newly built ones. The goal is *not* to replace Time Molecules’ process-oriented Markov workflow with a Data Vault. Instead, Data Vault acts as the durable, scalable bridge that ingests raw event data from TimeSolution while preserving the ability to feed (or coexist with) conventional dimensional models and modern semantic layers.

As noted in the companion star-schema tutorial (which reshapes `dbo.EventsFact + dbo.EventPropertiesParsed + dbo.CasePropertiesParsed` into fact/dimension tables as a *downstream* step), the Event Ensemble already contains the raw ingredients for BI. Data Vault simply makes that ingestion enterprise-grade, auditable, and mesh-friendly so the same event data can power both Time Molecules discovery *and* traditional BI reporting without duplication or conflict.

This directory focuses on the Data Vault linkage pattern, extending the star-schema ideas to a full Data Mesh architecture where:
- **EventsFact** and **metric event properties** become the core facts (loaded into Hubs/Links).
- **Properties** (sourced from `EventPropertiesParsed`, `CasePropertiesParsed`, source systems, or external semantic layers) become Satellites.

At the customer-facing level, analysts and business users see only a modern, governed **semantic layer** (powered by Kyvos) rather than raw tables or vaults.

### Why this exists

Many organizations already operate mature traditional BI environments (star schemas, OLAP cubes, or data marts) and want to incorporate Time Molecules’ process-behavior insights without rebuilding everything. Data Vault provides the missing “versatile data warehouse” layer that:
- Accepts raw, unaltered event streams from TimeSolution (bronze/raw layer).
- Applies business rules and cleansing once (silver/business layer).
- Feeds both existing BI marts *and* new domain data products.

This mirrors exactly what the author described in the blog *Embedding a Data Vault in a Data Mesh*:

> “The Data Vault layer provides a versatile data structure where data from many domains and stages can exist in one place, while allowing flexibility required by domains. The Data Vault is comprised of two parts: 1. The Raw Data Vault. It holds a historic, mostly unaltered version of data extracted from the OLTP sources. 2. The Business Vault (consumer-facing layer). It is a set of transformed tables built solely from the tables of the Raw Data Vault.”

The pattern also directly supports the user’s point about onboarding: raw event data lands immediately (“it’s there now—not pretty, but it’s there”), and transformations to silver/gold levels happen over time via the Business Vault.

### Abstract of Data Mesh Benefits (relevant to this use case)

**From the blog *[Embedding a Data Vault in a Data Mesh](https://eugeneasahara.com/2022/01/02/data-vault-data-mesh/)*:**  
Data Mesh decomposes monolithic EDWs into domain-owned Data Products while Data Vault supplies the shared, structured warehouse backbone. Key benefits for TimeSolution + BI integration:
- **Onboarding new data sources** becomes trivial—domains simply attach new satellites; no central team bottleneck.
- **Raw data is preserved** (bronze layer) while Business Vault handles the “T” of ELT in a governed, auditable way.
- **Star schema Data Marts** are extracted from the Business Vault and exposed as consumer-facing products.
- Overall: “Data Mesh with Data Vault … Facilitate[s] a comprehensive and up-to-date model of an enterprise … Mitigate[s] the change friction associated with dependencies through decomposition by domain boundaries … Scales out the development and maintenance efforts.”

**From Chapter 7 of *[Enterprise Intelligence](https://technicspub.com/enterprise-intelligence/)* (Asahara, 2024, p. 163):**  
Data Mesh expands the reach of BI by shifting from centralized BI teams to domain-owned data products with clear schemas, SLAs, and discoverability. It treats each domain (Sales, Finance, Operations, etc.) as a self-service data steward, relieving the central bottleneck while still enabling enterprise-wide composition through shared semantic models and knowledge graphs. In the TimeSolution context, this means event sequences and Markov models become reusable “process data products” that integrate cleanly into the broader mesh without forcing every consumer to learn the raw Event Ensemble.

### Main idea

The Event Ensemble (`dbo.EventsFact`, parsed properties, etc.) is the *source of truth for process behavior*. Data Vault is the *enterprise integration and persistence layer*. Traditional BI (star schemas) and the modern customer-facing semantic layer (Kyvos) sit downstream:

```
TimeSolution Event Ensemble
        ↓ (ingest via ELT)
Raw Data Vault (Hubs/Links/Satellites from EventsFact + properties)
        ↓ (business rules)
Business Vault
        ↓ (extract)
Star-schema Data Marts  ←→  Kyvos Semantic Layer (customer-facing)
```

**EventsFact + metric properties** → Fact-like Hubs/Links (grain = event or case).  
**Properties** (source, source columns, `PropertiesParsed`, external sources) → Satellites (descriptive, historically tracked, source-specific).

This is an *extension* of the star-schema tutorial: instead of directly building `FACT.Fuel_Weight`, you first land everything in Data Vault so the same data can serve multiple BI consumers and future domains.

### What is in this directory (and how to use it)


- **`raw_to_vault_example.sql`** – Example SQL showing how to load `dbo.EventsFact` and parsed properties into Data Vault Hubs/Links/Satellites (or views that map to an *existing* external Data Vault).
- **`business_vault_to_star_example.sql`** – How Business Vault tables feed conventional fact/dimension tables (extending the star-schema fact_table_example.sql).
- **`kyvos_registration.sql`** – Stored-proc calls to register the final semantic layer (see below).

### How to register the Kyvos Semantic Layer as the customer-facing view

Once Data Vault (or the Business Vault) is populated, the *only* layer business users see is the Kyvos semantic layer. Register it exactly as shown in the dedicated tutorial:

```sql
-- 1. Register Kyvos as the primary property / consumer source
EXEC dbo.InsertSource
    @SourceName = 'Kyvos_Semantic_Model',
    @SourceType = 'KYVOS_SEMANTIC_LAYER',
    @ConnectionString = 'kyvos://your-kyvos-server/semantics/your-model-id',
    @Description = 'Enterprise unified semantic model – curated measures, dimensions, hierarchies, and KPIs from Kyvos',
    @IsPropertySource = 1;
```

(Full details and additional `InsertSourceColumns` examples are in `[/tutorials/kyvos_semantic_layer_as_source](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/kyvos_semantic_layer_as_source)`—highly recommended read. Kyvos delivers sub-second performance on billions of rows, centralized governance, and consistent business definitions—perfect for the “one view, one meaning” that Data Mesh demands.)

### When to use this pattern

- You have (or plan to build) a Data Vault and want TimeSolution events to participate in it.
- Existing BI marts must be fed without duplicating event data.
- You want domain teams to own their data products while still benefiting from Time Molecules process discovery.
- Business users should interact only with a governed semantic layer (Kyvos), never raw vaults or tables.

### When not to mistake this for the main point

Data Vault is the *bridge*, not the destination. The distinctive value of Time Molecules remains the Markov-model workflow: detect behavioral differences first, *then* use the vault → star → Kyvos path to explain *why* those differences matter with governed dimensions and measures.

### Suggested next steps

1. Ingest a small set of `EventsFact` rows into your (existing or new) Raw Data Vault.
2. Build the corresponding Satellites from parsed properties.
3. Extract a test star-schema fact table from the Business Vault (reuse the pattern from `/tutorials/star_schema`).
4. Register the final Kyvos semantic model and validate that business users can slice Markov results by Kyvos-defined hierarchies.

That sequence gives you the best of all worlds: Time Molecules for process intelligence + Data Vault for scalable integration + Data Mesh for domain ownership + Kyvos for the modern, customer-facing semantic layer.



For Kyvos registration details:  
`/tutorials/kyvos_semantic_layer_as_source` (and the official Kyvos Unified Semantic Foundation documentation).

