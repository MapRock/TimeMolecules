# Star Schema from the Event Ensemble

This tutorial shows how to derive a conventional dimensional model from the **Event Ensemble** in Time Molecules. The goal is not to replace the main Time Molecules workflow with a star schema. The goal is to show how event-centered data can be reshaped into familiar BI structures **after** the more distinctive Time Molecules work has been done. This is an extension of what I mention on page 126 of my book [Time Molecules](https://technicspub.com/time-molecules/): Open Schema Properties to an Outrigger Dimension Table

In Time Molecules, the primary analytic path is:

1. Build or compare Markov models from event streams.
2. Detect where process behavior differs in a meaningful way.
3. Drill through to the underlying events and cases.
4. Analyze the associated event and case properties in a conventional BI form.

This directory focuses on step 4.

## Why this exists

Many BI teams still think most naturally in terms of:

- **fact tables** for measurable activity
- **dimension tables** for descriptive context
- slicing, dicing, filtering, and comparing through star or snowflake schemas

That style of modeling is still valuable. The Event Ensemble already contains the raw ingredients for it:

- `dbo.EventsFact` for the event grain
- `dbo.EventPropertiesParsed` for event-level attributes and measures
- `dbo.CasePropertiesParsed` for case-level attributes and context

This means a conventional fact table can often be assembled directly from event rows plus parsed event and case properties.

## What is in this directory

### `fact_table_example.sql`

A small example showing how to build a fact-style rowset from:

- `EventsFact` as the event grain
- event-level numeric properties such as `Fuel` and `Weight`
- a case-level property such as `LocationID`

The example joins:

- `dbo.EventsFact`
- `dbo.EventPropertiesParsed`
- `dbo.CasePropertiesParsed`

and produces a result shaped like a dimensional fact table, suitable for saving into a `FACT` schema such as `FACT.Fuel_Weight`. The sample uses `LocationID` as a dimension-style key and treats `Fuel` and `Weight` as numeric measures. :contentReference[oaicite:0]{index=0}

## Main idea

A dimensional model here is a **downstream analytic form** of the Event Ensemble, not the central destination of Time Molecules.

That distinction matters.

The main point of Time Molecules is to understand **process behavior over time**:

- what tends to happen next
- where processes differ
- which changes are meaningful
- how to drill through from those differences to the underlying cases and events

Once those areas of difference are isolated, a fact table or dimension table becomes a practical way to study the related attributes in a familiar BI toolset. In other words, the star schema is not the first lens. It is a supporting lens that becomes especially useful after process-oriented differences have already been identified. :contentReference[oaicite:1]{index=1}

## How to think about the grain

The example in this directory uses the **event** as the fact grain.

That is a natural fit because many operational fact tables are effectively event-driven even when they are not always described that way. An event row can then be enriched by:

- event properties for measures or event-specific descriptors
- case properties for broader contextual dimensions
- surrogate keys or natural keys for downstream dimensions

This makes the Event Ensemble a useful source for “silver medallion” star or snowflake schemas derived from the underlying “bronze medallion” event layer. :contentReference[oaicite:2]{index=2}

## When to use this pattern

Use this pattern when you want to:

- publish event-derived analytics to conventional BI tools
- expose familiar fact-and-dimension structures to analysts
- compare attributes associated with cases or events after a Time Molecules drill-through
- support descriptive BI alongside process-oriented analysis

## When not to mistake this for the main point

Do not read this directory as saying that Time Molecules is “just another way to make a star schema.”

That is not the point.

The dimensional model is useful, but it is downstream of the more distinctive Time Molecules workflow:

- detect behavioral differences in Markov models first
- then use event and case properties to explain those differences through more conventional BI structures

That sequence is the key idea behind this tutorial. 

## Suggested next steps

After reviewing this directory, a useful next progression would be:

1. create a simple fact table from `EventsFact`
2. add one or two dimensions derived from parsed case properties
3. test the resulting schema in a BI tool
4. compare that output with what you learn from Markov-model-based drill-through

That comparison helps clarify what conventional dimensional analysis can explain well, and where the process-oriented Time Molecules view adds something distinctive.

## Summary

This directory demonstrates how the Event Ensemble can be reshaped into a conventional star-schema-friendly form. It uses event rows as the fact grain, joins parsed event and case properties, and shows how familiar BI structures can be created from Time Molecules data. The important framing, however, is that these structures are not the main destination. They are a practical downstream representation used to study the properties associated with process differences already surfaced by Time Molecules.
