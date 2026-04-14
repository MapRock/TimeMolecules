
# Skill: Build an Output-to-Input Object Mapping from TimeSolution Metadata

## Purpose

This skill creates a metadata-derived web showing how SQL Server objects in TimeSolution may work together.

The basic idea is to map outputs from one object to inputs of another object. For example, if one stored procedure returns or writes a `ModelID`, and another stored procedure accepts `@ModelID`, that suggests a possible operational relationship between the two objects.

This is not guaranteed execution lineage. It is an inferred object-relationship map based on metadata.

## Original Prompt

look at this file: https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv

that csv contains the parametersjson (input) and outputnotes (output). using your superior intellect, what i want is a web that points outputs from one stored procedure, tvf, scalar, to the inputs of another. there are of course many parameters and output columns, to there will many pointing to many. output as a csv the from object, from output column, input object, parameter that it points to.

## Source Metadata

The source metadata file is:

https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/TimeMolecules_Metadata.csv

Important fields:

- `ObjectName`
- `ObjectType`
- `ParametersJson`
- `OutputNotes`
- `Description`
- `Utilization`

For this skill, the most important fields are:

- `ParametersJson`: describes object inputs
- `OutputNotes`: describes object outputs

## Output File

The generated output lives here:

https://github.com/MapRock/TimeMolecules/blob/main/data/timesolution_schema/timesolution_output_to_input_edges.csv

The output CSV has this structure:

```csv
from_object,from_output_column,input_object,parameter
````

## Meaning of the Output

Each row represents a possible edge:

```text
from_object.from_output_column  ->  input_object.parameter
```

For example, if object A produces `ModelID`, and object B accepts `@ModelID`, the CSV may contain:

```csv
dbo.SomeProcedure,ModelID,dbo.AnotherProcedure,@ModelID
```

This means:

> The output of `dbo.SomeProcedure` may be usable as an input to `dbo.AnotherProcedure`.

## How the Mapping Is Created

The process is:

1. Read `TimeMolecules_Metadata.csv`.
2. Keep SQL executable/query objects such as:

   * stored procedures
   * table-valued functions
   * inline table-valued functions
   * scalar functions
3. Parse each object’s `ParametersJson` to identify input parameters.
4. Parse each object’s `OutputNotes` to identify output columns or output values.
5. Normalize names so that small differences do not prevent a match:

   * remove `@`
   * remove brackets
   * lowercase
   * split or simplify identifier-like names where appropriate
6. Compare output names to input parameter names.
7. Write one row for each likely output-to-input match.

## How This Can Be Used

This file helps answer questions such as:

* Which object might be called after this one?
* Which stored procedures appear to produce values needed by other procedures?
* What objects consume `ModelID`, `CaseID`, `EventSet`, or similar values?
* How might an AI agent chain TimeSolution objects together?
* Which objects are operationally related even if they do not directly call each other?
* What possible workflows exist across stored procedures, TVFs, and functions?

## Why This Matters for AI Agents

An AI agent needs more than object descriptions. It needs hints about possible movement through the system.

This mapping gives the agent a lightweight routing graph:

```text
object output -> another object input
```

That can help the agent infer possible next steps during orchestration.

For example:

1. Find an object that creates or returns a `ModelID`.
2. Find other objects that accept `@ModelID`.
3. Suggest those objects as possible next calls.
4. Use descriptions and utilization metadata to decide which next call makes sense.

## Important Caveat

This file is an inferred metadata graph, not a guaranteed execution graph.

A match means:

> These objects may work together because one appears to produce a value that another accepts.

It does not prove:

* the first object directly calls the second
* the output is always compatible
* the workflow is always valid
* the objects should always be chained together

The mapping should be used as guidance for discovery, orchestration, documentation, and LLM grounding.
