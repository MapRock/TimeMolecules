
# Input / Output Map for Stored Procedures, TVFs, and Scalar Functions

This tutorial explains one of the most important structural assets in **Time Molecules** for AI-assisted orchestration: a normalized map of **what programmable database objects take in, what they produce, and what they reference**.

The objects covered here include:

- **Stored procedures**
- **Table-valued functions (TVFs)**
- **Scalar functions**

This map is not the whole story of agentic execution, but it is a critical part of it. If an AI agent is going to compose workflows instead of merely calling isolated procedures, it must understand how one object’s outputs can satisfy another object’s inputs. That is what this tutorial is about.

---

## Why this matters for AI agents

A human developer can often infer that:

- one procedure returns a `ModelID`
- another procedure accepts a `ModelID`
- a function emits a probability or transition measure
- another object expects that value as a filter, parameter, or control input

An AI agent needs that same knowledge in a more explicit form.

This tutorial provides a practical map of those relationships so agents can begin to reason about:

- **what object to call first**
- **what can be called next**
- **which outputs are reusable**
- **which referenced tables or helper objects are involved**
- **how to compose a multi-step workflow instead of a single call**

In other words, this directory helps bridge the gap between a flat inventory of SQL objects and a **workflow-aware tool graph**.

---

## What is in this directory

### 1. `TimeMolecules_Objects.csv`

This file is the **object-level catalog**.

Each row represents one programmable object and includes fields such as:

- object type
- object name
- object description
- utilization
- sample code

This gives an LLM or agent a compact semantic summary of what an object is for before it tries to use it.

Typical use cases:

- embedding object descriptions for semantic search
- choosing the best candidate object for a task
- showing humans or agents a concise catalog of available database tools

---

### 2. `TimeMolecules_Object_Items.csv`

This file is the **detail-level catalog**.

Each row describes one item related to an object, grouped into categories such as:

- **Input**
- **Output**
- **Reference**

Examples include:

- input parameters like `@ModelID`, `@EventSet`, or `@StartDateTime`
- output result columns or scalar return values
- referenced tables, built-in functions, or other dependent objects

This is the more operational file. It is the file that begins to expose how objects can connect to one another.

Typical use cases:

- mapping outputs from one object to inputs of another
- identifying workflow dependencies
- helping an agent infer execution order
- exposing object dependencies for reasoning, lineage, or debugging

---

### 3. `parse_parameters_outputs.py`

This script creates the normalized CSVs from the main metadata source.

Conceptually, it does three things:

1. Loads the source metadata file
2. Filters for programmable objects that actually have parameter metadata
3. Splits the metadata into:
   - an **object catalog**
   - an **object-items catalog** for inputs, outputs, and references

This is important because raw metadata is often too nested or irregular for direct agent use. The script turns it into a shape that is much easier to search, embed, compare, and connect.

---

### 4. `input_output_query_prompt.txt`

This is an [LLM prompt template](https://github.com/MapRock/TimeMolecules/blob/main/docs/important_notes.md#frontier-model-intermittently-will-not-read-urls-in-the-prompt) that will read some metadata and answer a question.

This prompt should be used for questions that will help to compose a workflow from the sprocs and functions.

The parameters that must be filled:

- **{question}:** The question we want to ask.

**Warning**: This template includes two URLs to CSV files. See note on [LLMs occassionally refusing to read URL](https://github.com/MapRock/TimeMolecules/blob/main/README.md#notes)s.

## The larger idea

This directory is really about building an **interface map** for database logic.

A stored procedure or function should not be treated as just a block of code. For AI workflow composition, each object is better understood as something like this:

- it has a **purpose**
- it has **inputs**
- it has **outputs**
- it has **dependencies**
- it occupies a place in a larger graph of executable possibilities

Once that map exists, the objects can begin to behave more like **tools in a toolset** rather than isolated SQL artifacts.

That makes it possible to move toward:

- tool selection
- workflow composition
- dependency-aware execution
- multi-step reasoning over SQL capabilities

---

## What an agent can do with this map

With enough supporting logic, an AI agent could use this tutorial’s outputs to do things like:

### Discover candidate tools
Search descriptions and utilization text to find objects related to a user request.

### Match outputs to downstream inputs
Infer that the output of one object can be passed to another object’s parameter.

### Build workflow chains
Construct ordered calls such as:

- get or create an event set
- generate a model
- inspect model segments
- compute Bayesian or Markov-derived statistics
- drill through to cases or events

### Explain why a workflow was chosen
Show the path of reasoning in terms of object descriptions, parameter compatibility, and referenced dependencies.

### Reduce hallucination
Ground workflow generation in actual object metadata instead of pure guesswork.

---

## What this map does **not** do by itself

This tutorial is central, but it is not sufficient on its own.

An agent still needs additional capabilities such as:

- parameter-value generation
- type and shape validation
- business-rule awareness
- permissions and execution safety
- understanding of required sequencing beyond simple I/O matching
- handling of optional parameters, defaults, and side effects
- awareness of temporary tables, work tables, and session behavior

So this tutorial should be seen as a **critical structural map**, not the entire orchestration system.

---

## How to think about it

A helpful way to think about this directory is:

- `TimeMolecules_Objects.csv` tells you **what each tool is**
- `TimeMolecules_Object_Items.csv` tells you **how the tool interfaces with the world**
- `parse_parameters_outputs.py` tells you **how the map was built**

Together, they form a practical starting point for turning a SQL codebase into something an AI agent can navigate.

---

## Recommended next step

A natural next step after this tutorial is to create a third file that explicitly stores inferred relationships such as:

- `output_object`
- `output_column`
- `input_object`
- `input_parameter`

That turns a metadata catalog into an actual **composition graph**.

At that point, an agent is no longer just searching for procedures. It is beginning to understand how to assemble them into workflows.




[1]: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/input_output_map_stored_procs_functions "TimeMolecules/tutorials/input_output_map_stored_procs_functions at main · MapRock/TimeMolecules · GitHub"
[2]: https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/input_output_map_stored_procs_functions/TimeMolecules_Objects.csv "raw.githubusercontent.com"
