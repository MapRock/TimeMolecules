# LLM-Assisted Object Descriptions in Time Molecules

On page 212 of *Time Molecules*, in the section **“Generate LLM Prompts for Generating Object Descriptions,”** I introduce the idea of generating prompt text from TimeSolution metadata so an LLM can help create useful descriptions for system objects. This tutorial extends that idea in a more practical, GitHub-oriented direction. :contentReference[oaicite:0]{index=0}

## Purpose

Time Molecules is meant to ingest events and related metadata liberally. That is intentional. In many real systems, new events, event sets, transforms, models, sources, and columns arrive long before anyone has written polished descriptions for them. Rather than forcing everything to be fully documented up front, Time Molecules allows us to bring the objects in first and fill in the blanks later.

This is one concrete way LLMs can be a component of the Time Molecules approach.

The stored procedure `dbo.Generate_LLM_Description_Prompts` already provides a strong foundation for this. It generates natural-language prompts for major TimeSolution metadata objects, including EventSets, Transforms, Metrics, Sources, SourceColumns, Models, and CaseTypes, so those objects can be described, embedded, indexed, or otherwise enriched. :contentReference[oaicite:1]{index=1} :contentReference[oaicite:2]{index=2}

## Why This Matters

The important idea is not just “use an LLM to write a description.” The deeper idea is that the system itself supplies context for the LLM.

For example:

- an **EventSet** prompt can include its associated case types
- a **Model** prompt can include its serialized Markov transitions and model properties
- a **Source** prompt can include its list of columns
- a **SourceColumn** prompt can include table name, data type, and whether it is a key

That means the LLM is not guessing from a bare label. It is being given structured context from TimeSolution itself. The result is often a much more sensible description than what would be written manually in the early stages of ingestion. The book shows this with the `pokeractions` event set and with a restaurant-service Markov model, where generated prompts are turned into usable human-readable descriptions. :contentReference[oaicite:3]{index=3}

## The Larger Point

This tutorial is really about a design pattern:

1. **Ingest liberally.**  
   Bring in events and metadata even when some descriptive fields are incomplete.

2. **Generate context-rich prompts from the metadata model.**  
   Use `dbo.Generate_LLM_Description_Prompts` to create grounded prompts based on existing structure in TimeSolution. :contentReference[oaicite:4]{index=4}

3. **Ask an LLM for a concise description, and possibly an IRI.**  
   The LLM is a helper component here, not the system of record.

4. **Persist the result back into the metadata tables.**  
   Update `[Description]`, optionally `[IRI]`, and also update `[LastUpdate]`.

5. **Reuse the enriched metadata downstream.**  
   Those values can help with vector search, semantic web integration, knowledge graphs, RAG, or fine-tuning. 

That is the real role of the LLM here: not replacing Time Molecules, but helping Time Molecules enrich itself after ingestion.

## Relationship to the Agent Retrofit Work

The Python below follows the same general design style used in `auto_generate_sensible_object_description.py`:

- upward `.env` discovery
- configurable `OpenAI` or `Ollama` backends
- `pyodbc` connection to SQL Server
- an abstraction layer around LLM calls rather than hardwiring one provider

That is deliberate. I want this to feel like part of the same family of tooling rather than a disconnected one-off script.

## What the Script Does

The script below:

- executes `dbo.Generate_LLM_Description_Prompts`
- optionally filters to one table such as `EventSets` or `Models`
- optionally limits work to rows missing descriptions
- sends each generated prompt to either OpenAI or Ollama
- expects back JSON containing:
  - `Description`
  - optional `IRI`
- updates the corresponding metadata row
- updates `LastUpdate` using `SYSUTCDATETIME()`

