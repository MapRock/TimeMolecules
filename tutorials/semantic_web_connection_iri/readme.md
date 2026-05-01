
# Semantic Web IRIs in Time Molecules

**Tutorial 01: The Universal Link – `[dbo].[vwTimeSolutionsMetadata]` and the `IRI` column**

The `IRI` column is the **semantic glue** that turns your TimeSolution metadata from a simple catalog into a true **enterprise knowledge graph**.

Every object in Time Molecules (tables, columns, stored procedures, event types, models, sources, etc.) can now be uniquely identified and linked to the Semantic Web using an **International Resource Identifier (IRI)**.

This is the same concept you already use with Wikidata QIDs, RDF, and Prolog grounding in your blog posts.

### 1. What is `vwTimeSolutionsMetadata`?

This is the **single source of truth** for all TimeSolution metadata.

- It unions metadata from:
  - Database objects (`sys.objects`, columns, procedures, functions, views…)
  - Time Molecules–specific tables (`CaseTypes`, `EventTypes`, `Models`, `Sources`, `DimEvents`, etc.)
  - LLM prompts and tutorial content
- It powers the Qdrant vector index (`build_qdrant_index.py`)
- It includes the `IRI` column for every row

**Key columns** (from `TimeMolecules_Metadata.csv` and the view):

| Column                | Purpose |
|-----------------------|---------|
| `ObjectType`          | Table, Column, SQL_STORED_PROCEDURE, Instance, VIEW, LLM_PROMPT… |
| `ObjectName`          | Fully qualified name |
| `Description`         | Human + machine readable description |
| `IRI`                 | **The semantic link** (the star of this tutorial) |
| `Utilization`, `SampleCode`, `ParametersJson`… | Context for the AI agent |

### 2. What does an IRI look like?

Current examples in the system use two styles:

1. **Internal Time Molecules IRIs** (recommended for now):
   - `https://eugeneasahara.com/timemolecules#EventType.arrive`
   - `https://eugeneasahara.com/timemolecules#Source.EHR.UnknownTable.Panel`
   - `https://eugeneasahara.com/timemolecules#Model.1`

2. **External Semantic Web links** (future-proof):
   - `https://www.wikidata.org/entity/Q11506` (maize)
   - Your own ontology: `https://data.yourcompany.com/ns/case#PatientVisit-73`

You can see `@IRI` parameters already in `InsertSource`, `get_semantic_web_llm_values`, and columns like `DimEvents.IRI`, `CaseTypes.IRI`, etc.

### 3. Quick SQL exploration

```sql
-- 1. See the view structure
SELECT TOP 20 
    ObjectType, 
    ObjectName, 
    IRI,
    Description
FROM dbo.vwTimeSolutionsMetadata
WHERE IRI IS NOT NULL
ORDER BY ObjectType, ObjectName;

-- 2. Find everything linked to a specific concept
SELECT ObjectName, ObjectType, Description
FROM dbo.vwTimeSolutionsMetadata
WHERE IRI LIKE '%EventType.arrive%';

-- 3. Objects that have semantic web grounding
SELECT ObjectType, COUNT(*) as count
FROM dbo.vwTimeSolutionsMetadata
WHERE IRI IS NOT NULL
GROUP BY ObjectType;
```

### 4. How the AI Agent will use IRI (new skill)

The current `DiscoveryAgent` already pulls from `vwTimeSolutionsMetadata` via Qdrant.

We will now teach the agent to:
- Recognize when an IRI is present in hits
- Resolve/follow IRIs for richer context
- Generate SPARQL, JSON-LD, or Prolog snippets
- Ground user questions to external knowledge (Wikidata, your ontology, etc.)

### 5. New LLM Prompt Pattern (add this file)

Create: `tutorials/semantic_web_iri/iri_resolution_prompt.txt`

```txt
You are an expert in Time Molecules and the Semantic Web.

User question:
{user_prompt}

Retrieved Time Molecules metadata (with IRIs):
{context}

When an object has a non-empty IRI field:
- Treat the IRI as the canonical global identifier.
- If the IRI points to Wikidata or another ontology, expand the answer with that external knowledge.
- Prefer IRI-based reasoning over plain object names.
- If asked about semantic links, relationships, or "what is X connected to", use the IRI.

Answer the user question using the metadata and any IRI links.
Be precise, cite the IRI when relevant, and suggest follow-up semantic queries when useful.
```

### 6. Next steps (what to do after this tutorial)

1. Add `IRI` to the Qdrant payload in `build_qdrant_index.py` (it’s probably already there via the view).
2. Update `DiscoveryAgent` and `build_context_from_hits` to display `IRI` prominently.
3. Add a new `SemanticWebAgent` or extend `GuidanceAgent` to call the new prompt.
4. Create a follow-up tutorial on **IRI resolution + Wikidata** using the agent.

