**Short Tutorial: Using the Input/Output Query Prompt for Time Molecules**

### Purpose
The file `input_output_query_prompt.txt` is a **ready-to-use system prompt** that turns any LLM into an expert on the inputs, outputs, parameters, and relationships of every stored procedure, table-valued function (TVF), scalar function, view, and table in a TimeSolution database.

It forces the model to load and reason from two small, normalized metadata CSVs before answering questions — making it perfect for workflow composition, tool discovery, and chaining database objects.

### Files It Uses
- **`TimeMolecules_Objects.csv`** — High-level catalog of every database object (name, type, description, sample code, etc.)
- **`TimeMolecules_Object_Items.csv`** — Detailed breakdown of every input parameter and every output column/item

Both files live here:  
[https://github.com/MapRock/TimeMolecules/tree/main/tutorials/input_output_map_stored_procs_functions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/input_output_map_stored_procs_functions)

### How to Use It (3 Simple Steps)

1. **Copy the prompt**  
   Go to:  
   [input_output_query_prompt.txt](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/input_output_map_stored_procs_functions/input_output_query_prompt.txt)  
   and copy the entire contents.

2. **Replace the placeholder**  
   Find `{question}` and insert your actual question.

3. **Send it to an LLM**  
   Paste the full prompt (with your question) as the first message.  
   The LLM will automatically load the two CSVs (via URL or upload) and answer accurately.

### Example Questions
- What objects output a `ModelID` that I can use as input for another procedure?
- What are the required input parameters for `[dbo].[MarkovProcess2]`?
- Which objects produce `MetricValue` or `CaseID`?
- Show me a possible workflow to create a Markov Model from raw events.

### Tips for Best Results
- Ask **specific** questions about data flow, inputs/outputs, or dependencies.
- Combine with other prompts from the `docs/llm_prompts/` folder for full AI-agent power.
- The CSVs are tiny (< 200 KB) — most modern LLMs can load them directly from the raw GitHub URLs.
- Great for planning multi-step automations or building agent tool-calling logic.

That’s it! This one prompt turns the entire TimeSolution object catalog into an easily queryable, composable toolkit. Use it whenever you need to understand **what goes in** and **what comes out** of any database object.
