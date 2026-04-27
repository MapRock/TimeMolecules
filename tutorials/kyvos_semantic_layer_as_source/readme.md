
## Kyvos Semantic Layer as a Primary Property Source

One of the major pillars of Time Molecules is the clean separation between **stories** (event sequences / cases) and **properties** (the curated, governed facts and dimensions that describe the things involved in those stories).

The **Kyvos Semantic Layer** is an ideal, enterprise-grade source for the *property side* of Time Molecules.

### Why the Kyvos Semantic Layer fits perfectly

Kyvos delivers a modern **universal semantic layer** — a single, governed, business-friendly model built directly on top of data lakes, warehouses, or MPP platforms. It provides:

- Consistent, reusable definitions of measures, dimensions, hierarchies, and calculations
- Sub-second performance even on billions of rows
- Full support for time intelligence, what-if analysis, and complex business logic
- Centralized governance, security, and lineage

In Time Molecules terms, the Kyvos semantic layer is your **primary property source** — the authoritative “thing-centric” backbone that enriches every case and event with reliable context.

While Time Molecules focuses on the *time-side* (event sequences + Markov abstractions), Kyvos supplies the high-quality *thing-side* facts and dimensions that make those stories meaningful and comparable across the enterprise.

**Best official explanation** (highly recommended read):  
[Kyvos Unified Semantic Foundation](https://www.kyvosinsights.com/semantic-layer/unified-semantic-foundation/)

### How to register Kyvos as a Property Source in TimeSolution

Use the two stored procedures you already have in the repo:

```sql
-- 1. Register the Kyvos semantic model as a source
EXEC dbo.InsertSource
    @SourceName = 'Kyvos_Semantic_Model',
    @SourceType = 'KYVOS_SEMANTIC_LAYER',
    @ConnectionString = 'kyvos://your-kyvos-server/semantics/your-model-id',  -- adjust as needed
    @Description = 'Enterprise unified semantic model – curated measures, dimensions, hierarchies, and KPIs from Kyvos',
    @IsPropertySource = 1;

-- 2. Register the columns / measures / dimensions you want to expose
EXEC dbo.InsertSourceColumns
    @SourceName = 'Kyvos_Semantic_Model',
    @ColumnName = 'CustomerSegment',      -- example
    @DataType = 'NVARCHAR(100)',
    @IsKey = 0,
    @Description = 'Customer segmentation hierarchy from Kyvos semantic layer';

-- Repeat for any other dimensions/measures you want available as properties
```

Once registered, Time Molecules can:

- Pull any dimension attribute or measure from the Kyvos semantic layer
- Join those properties to event data at query time or during case materialization
- Use Kyvos-calculated metrics (YTD, QoQ, rolling averages, custom KPIs) as stable properties inside Markov models
- Slice and dice Markov models by any hierarchy or dimension defined in Kyvos (exactly like traditional OLAP)

### Recommended usage patterns

1. **Primary property enrichment** — Let Kyvos be the single source of truth for all governed business dimensions and metrics.
2. **Hybrid analysis** — Combine Kyvos properties with raw event streams to create rich, context-aware cases.
3. **Consistent slicing** — When you dice a Markov model by “Customer Segment” or “Product Category”, the definitions come straight from Kyvos — guaranteeing enterprise-wide consistency.
4. **Performance** — Kyvos’ massively parallel engine does the heavy analytical lifting so Time Molecules can stay focused on process discovery.

### Why this combination is powerful

Traditional BI gave us excellent thing-centric analysis through semantic layers.  
Time Molecules adds the missing *time-centric* counterpart.

By using Kyvos as the primary property source, you get the best of both worlds:

- **Governed, curated, business-aligned facts** → Kyvos semantic layer  
- **Living, interacting process stories** → Time Molecules event sequences + Markov abstractions

Together they create true **process-aware intelligence** at enterprise scale.

**Shout-out to the Kyvos team** — your semantic layer is exactly the kind of mature, high-performance, governed foundation that makes advanced process analysis practical at real-world scale.

For more details on connecting external semantic layers, see `docs/sources/property_sources.md` and the LLM prompts in `docs/llm_prompts/`.

