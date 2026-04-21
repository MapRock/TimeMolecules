# Property-Level MDM and Semantic Mapping for Case and Event Properties

> **Warning:** This capability is **not yet fully implemented** in Time Solution. The tables described here exist in the schema, and their intended role is clear, but the operational stewardship workflow and downstream usage are still incomplete. I plan to implement this more fully in the next refresh.

## Purpose

`CasePropertiesMDM` and `EventPropertiesMDM` are intended to provide a master-data and semantic overlay for case and event properties. They are not required for event ingestion, and they are not meant to be populated by the normal event-loading process. Instead, they are intended to be curated separately, most likely by data stewards or another governance process. :contentReference[oaicite:0]{index=0}

Their purpose is similar in spirit to event `Transforms`, but at the **property-value** level rather than the event-name level. A raw property value coming from a source column can be matched to a mastered value, linked to an IRI, and optionally placed into a parent-child hierarchy for drill-up and drill-down. 

## Why these tables exist

The parsed property tables capture what was observed:

- `CasePropertiesParsed` stores case-level property values such as `PropertyName`, `PropertyValueNumeric`, `PropertyValueAlpha`, and `SourceColumnID`. :contentReference[oaicite:2]{index=2}
- `EventPropertiesParsed` stores event-level property values with similar columns, plus `PropertySource`, `EventID`, and contextual event attributes. :contentReference[oaicite:3]{index=3}

Those parsed tables are useful for filtering and analysis, but they do not by themselves provide a governed semantic identity. That is where the MDM tables come in.

`CasePropertiesMDM` and `EventPropertiesMDM` are meant to say:

- this raw property value corresponds to this mastered value
- this mastered value may have an IRI
- this mastered value may roll up to a parent mastered value
- this match may be exact or approximate
- this mapping may evolve over time through stewardship rather than ingestion logic

## The two tables

### `CasePropertiesMDM`

`CasePropertiesMDM` is intended to hold mastered mappings for case-level properties. It includes the source-side identity (`SourceColumnID`, `PropertyName`, and raw property value), the mastered-side identity (`MDMSourceColumnID`, `MDMName`, and mastered value), governance/versioning fields, similarity logic, an optional semantic web IRI, and a parent pointer for hierarchy. :contentReference[oaicite:4]{index=4}

Important columns include:

- `SourceColumnID`
- `PropertyName`
- `PropertyValueNumeric`
- `PropertyValueAlpha`
- `MDMSourceColumnID`
- `MDMName`
- `MDMValueNumeric`
- `MDMValueAlpha`
- `MDMVersionID`
- `SimilarityScore`
- `MDMComparisonTypeID`
- `MDM_Parent_CasePropertiesMDMID`
- `MDM_IRI` :contentReference[oaicite:5]{index=5}

### `EventPropertiesMDM`

`EventPropertiesMDM` serves the same purpose for event-level properties. It has nearly the same shape, though in the current DDL it does not include `MDMVersionID`, while it does include the semantic and hierarchical fields needed for stewardship and drill-up/drill-down. :contentReference[oaicite:6]{index=6}

Important columns include:

- `SourceColumnID`
- `PropertyName`
- `PropertyValueNumeric`
- `PropertyValueAlpha`
- `MDMSourceColumnID`
- `MDMName`
- `MDMValueNumeric`
- `MDMValueAlpha`
- `SimilarityScore`
- `MDMComparisonTypeID`
- `MDM_IRI`
- `MDM_Parent_EventPropertiesMDMID` :contentReference[oaicite:7]{index=7}

## How this is intended to work

The intended pattern is:

1. **Ingest events and properties liberally** into the core event and parsed-property tables.
2. **Do not require MDM mapping during ingestion.**
3. **Later, in a separate stewardship process**, curate mappings from raw property values to mastered values.
4. Use those mappings to support:
   - semantic web linkage
   - property normalization
   - hierarchy-based drill-up and drill-down
   - cross-source alignment of similar property values

This separation matters. Event ingestion should focus on capturing the event stream. Stewardship should focus on improving semantic identity and consistency over time. That is why these tables are intended to be populated outside the event-loading process.

Because these MDM mappings normalize and semantically anchor case and event property values, Markov models could also be created on top of those mastered properties rather than only on the raw source-side values.

## Not every mapping must be exact

The existence of `SimilarityScore` and `MDMComparisonTypeID` shows that the intended design is broader than exact equality. `MDMComparisonTypes` is explicitly described as applying to these two MDM tables and as supporting cases such as GPS coordinates, where the comparison may not be exact and should instead be normalized to a score between 0 and 1. :contentReference[oaicite:8]{index=8}

This means the intended design supports at least two kinds of mapping:

- **exact mapping**, such as a code or name that cleanly maps to a mastered value
- **approximate mapping**, such as coordinates, fuzzy labels, or other values where similarity must be computed rather than assumed

That is important because many useful business properties are not simple exact-match categories.

## Semantic web linkage

A major purpose of these tables is to enable semantic web linkage at the property-value level, not just at the event or table level.

Time Solution already includes IRI-bearing structures in multiple places such as `CaseTypes`, `DimEvents`, `Metrics`, and `SourceColumns`. :contentReference[oaicite:9]{index=9} The MDM property tables extend that idea downward into the values of case and event properties themselves.

That means a steward should be able to say:

- this property value maps to a mastered value
- that mastered value corresponds to a semantic identifier
- therefore this raw observed property can now participate in linked-data style reasoning

This is especially useful when multiple source systems record the same concept differently.

## If there is no MDM, but there is an IRI

One important intended usage is that a property does **not** need a fully realized MDM taxonomy before it can be useful semantically.

If a property does not yet have a meaningful mastered value structure, but you do know the semantic identity, then it is still useful to populate the IRI. In that case, the MDM row can act first as a semantic anchor, even before the broader master-data structure is mature.

So the progression can be:

- raw property exists
- semantic identity is known
- IRI is populated
- fuller MDM standardization and hierarchy can come later

That makes these tables useful even before the stewardship process is fully complete.

## Hierarchy: drill-up and drill-down

The parent-child columns are important:

- `MDM_Parent_CasePropertiesMDMID`
- `MDM_Parent_EventPropertiesMDMID` 

These make it possible to define hierarchies among mastered values. That means a property mapping can support both:

- **drill-down** to a more specific mastered value
- **drill-up** to a broader category

For example, a very specific raw property value might map to a normalized mastered value, which in turn rolls up to a broader class. This gives the system more analytic flexibility and makes the property layer more consistent with OLAP-style navigation and knowledge-graph style classification.

## Similar to transforms, but for properties

A good intuition is:

- `Transforms` operate on **event names**
- `CasePropertiesMDM` and `EventPropertiesMDM` operate on **property values**

That makes them conceptually similar, but not the same.

A transform says that one event name should be treated as another. A property MDM mapping says that a raw property value should be treated as a governed mastered value, optionally with similarity scoring, hierarchy, and semantic identity.

## What a future implementation should do better

A fuller implementation in the next refresh should likely include:

- a more explicit stewardship workflow
- a clearer process for proposing and approving mappings
- better support for approximate matching and similarity scoring
- better use of IRIs when no mature MDM structure exists yet
- easier hierarchy maintenance for drill-up and drill-down
- clearer downstream usage by queries, skills, and knowledge-graph integration

In other words, the schema already expresses the intent well, but the operational layer around it still needs to be built out.

## Practical takeaway

These two tables are intended to let Time Solution move beyond raw property values toward governed, semantically meaningful property identities.

They are:

- optional
- steward-curated
- separate from event ingestion
- useful for semantic web linkage
- useful for hierarchy and drill navigation
- useful for approximate as well as exact matching

Even in their current incomplete state, they show the intended direction clearly: case and event properties should eventually be able to participate in the same kind of semantic and master-data discipline that Time Solution already applies to events, metrics, and other modeled structures.
