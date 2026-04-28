
## Overview of the AI Agent Workflow

This tutorial demonstrates a lightweight AI workbench for exploring Time Molecules using a combination of vector search and large language models. The core idea is simple: instead of manually searching code, metadata, and documentation, the system embeds your question, retrieves the most relevant objects, and then uses an LLM to interpret and explain the results.

At a high level, the workflow follows three steps:

1. **Embed the prompt** – Your question is converted into a vector using an embedding model.
2. **Search Qdrant** – The vector is used to retrieve the most relevant metadata objects (tables, procedures, functions, tutorials, etc.) from a Qdrant vector store.
3. **Analyze with an LLM** – The retrieved objects are passed to a language model, which identifies what matters, explains relationships, and produces a coherent answer.

Qdrant plays a critical role as the **retrieval layer**. It stores embeddings for all metadata and allows fast similarity search, making it possible to locate relevant objects without exact keyword matches. Without Qdrant, the system would lose its ability to semantically “find” the right pieces of the system.

The LLM provides the **reasoning layer**. This can be:

* a **local model via Ollama** (fully offline, no API cost), or
* a **frontier model** such as OpenAI or Grok (higher quality, but with cost and external dependency)

The choice of LLM affects answer quality and cost, but the overall workflow remains the same.

The application itself is written in Python and is intended to be run from **Visual Studio Code**. Setup instructions for the Python environment—including installing dependencies and configuring environment variables—are provided here:

[https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_python_env.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/setup_python_env.md)

Once configured, the app runs as a local desktop UI (Tkinter-based), allowing you to:

* enter prompts,
* inspect retrieved objects,
* load linked documentation,
* generate and execute SQL,
* and iteratively build context across multiple steps.

This architecture deliberately separates concerns:

* **Qdrant** handles retrieval,
* the **LLM** handles interpretation,
* and the **UI** acts as a workbench for composing and refining queries.

The result is a flexible environment that can operate at multiple levels—from simple metadata lookup to guided exploration of the Time Molecules system.


## Initial Opening – Control Overview


Figure 1 shows the initial opening of the Time Molecules AI-agent workbench. The numbered callouts highlight the key controls and interface elements that support the workflow, from prompt entry and Qdrant retrieval to LLM reasoning, SQL execution, and context management. The list below briefly describes each numbered component and its role in guiding the interaction.


![Figure 1 – Initial Opening](https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/ai_agent_skills/images/initial_opening.png)
*Figure 1 – Initial opening of the Time Molecules AI-agent workbench.*

Here’s a  mapping of each numbered UI element to what it does, based on your code:


### Prompt & Execution

**1. Prompt box**
Main input area. Accepts either natural language or SQL depending on the checkbox.

**2. Ask button**
Runs the workflow:

* embeds prompt
* queries Qdrant
* optionally calls LLM
* optionally executes SQL

**3. Results limit (spinbox)**
Controls how many Qdrant hits are retrieved.

**4. Use OpenAI to summarize retrieved hits**
If checked, runs the GuidanceAgent (LLM). If unchecked, just shows retrieved hits.

---

### Retrieval Behavior Controls

**5. Filter ObjectTypes first**
Uses LLM to classify which ObjectTypes to filter before querying Qdrant.

**6. Prompt is SQL**
Treats the prompt as raw SQL and executes it directly (bypasses LLM reasoning).

---

### Status & Context

**7. Status + spinner**
Shows current stage (e.g., “Embedding prompt”, “Done”, errors).

**8. Context chars (limit)**
Max size of rolling context memory used for follow-up prompts.

**9. Clear context**
Resets accumulated context summary.

---

### Retrieval Results

**10. Retrieved Objects (grid)**
Qdrant hits:

* ObjectName
* ObjectType
* similarity score

Selecting a row drives the lower panel.

---

### Selected Object Details

**11. Selected Item panel**
Shows:

* description
* utilization
* parameters
* sample code
* URLs (parsed for linking)

---

### Actions on Selected Object


**12. Generate sample SQL**
Creates and runs basic SQL for Tables/Columns.

**13. Linked URL dropdown**
All URLs extracted from selected item text.

---

### URL Actions

**14. Copy URL**
Copies selected URL to clipboard.

**15. Load Link**
Fetches content (GitHub raw / blog) and loads it into **Link Contents tab**.

---

### Results Tabs

**16. Answer tab**
LLM output or status text.

**17. Query Results tab**
Displays DataFrame results (via pandastable).

**18. Context tab**
Shows rolling context summary used across prompts.

**19. Link Contents tab**
Displays fetched content from GitHub/blog links.


---


## Initial Run with Defaults

After entering a prompt in the Prompt Input Box (2) and pressing Ask (3), the system begins by embedding the prompt and retrieving the top matches from Qdrant, shown in Retrieved Objects (12). As each stage progresses, the Status Bar (8) updates (e.g., searching Qdrant, waiting for the LLM), and the Progress Spinner (9) indicates active processing.

The default settings are chosen to strike a balance between accuracy, cost, and clarity of results:

The Top N (3) value is set to a moderate number (e.g., 5). This is usually sufficient to capture the correct object within the embedding space while avoiding excessive context being passed to the LLM. Too few results risks missing the correct object; too many increases token usage, cost, and the chance that the LLM is distracted by less relevant matches.
Filter ObjectTypes first (5) is disabled by default because it introduces an additional LLM call to classify object types before retrieval. While useful in some cases, this extra step adds latency and cost. In many scenarios, the embedding search alone is strong enough to surface the relevant objects without pre-filtering.

Use LLM (4) is enabled so that the system does more than just return matches. Instead of forcing the user to interpret raw metadata, the LLM takes the retrieved objects and:

identifies the most relevant ones,
explains how they relate to the prompt,
and synthesizes a coherent answer.

This effectively turns the embedding search into a guided analysis rather than a lookup.

Prompt is SQL (6) is disabled because the default interaction is conceptual or exploratory. The system assumes the prompt is a question about Time Molecules rather than executable SQL. Enabling this option bypasses reasoning and sends the text directly to the SQL engine, which is only appropriate when the user explicitly provides a query.

If Use LLM (4) is enabled, the retrieved metadata is passed to the LLM, which generates a synthesized response displayed in the Answer tab (16). If relevant SQL is inferred, it may be executed and displayed in the Query Results tab (16). Selecting any item in Retrieved Objects (12) populates Selected Item Details (13), where you can inspect descriptions, utilization, parameters, and sample code, or use actions like Generate Sample SQL (15).

At the same time, the workbench reconstructs a rolling context summary (if Context Size (10) is greater than zero), which is displayed in the Context tab (16). This summary captures the purpose of the query, key findings, and next steps, allowing subsequent prompts to build on prior work without replaying the full interaction history.

![Figure 2 – Initial Run](https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/ai_agent_skills/images/initial_run.png)
*Figure 2 – The result after pressing Ask using the sample prompt.*


After entering a prompt in the **Prompt Input Box (2)** and pressing **Ask (3)**, the system begins by embedding the prompt and retrieving the top matches from Qdrant, shown in **Retrieved Objects (12)**. As each stage progresses, the **Status Bar (8)** updates (e.g., searching Qdrant, waiting for the LLM), and the **Progress Spinner (9)** indicates active processing.

If **Use LLM (5)** is enabled, the retrieved metadata is then passed to the LLM, which generates a synthesized response displayed in the **Answer tab (16)**. If relevant SQL is inferred, it may be executed and displayed in the **Query Results tab (16)**. Selecting any item in **Retrieved Objects (12)** populates **Selected Item Details (13)**, where you can inspect descriptions, utilization, parameters, and sample code, or use actions like **Generate Sample SQL (15)**.

At the same time, the workbench reconstructs a rolling context summary (if **Context Size (10)** is greater than zero), which is displayed in the **Context tab (16)**. This summary captures the purpose of the query, key findings, and next steps, allowing subsequent prompts to build on prior work without replaying the full interaction history.


### Answer Tab (Working Memory Context Summary)

Figure 3 shows a close-up of the **Answer tab** after the **Ask** operation completes. Rather than simply returning a one-off response, the system produces a structured **working memory context summary** that captures the current state of the interaction.

The response is organized into sections:

* **Goal**
  This restates the user’s intent in normalized terms. In this case, the system recognizes that the user is looking for procedures that compute Markov models without persisting them. This step is important because it reframes the original prompt into something more precise and actionable.

* **Discoveries and Decisions**
  This section summarizes what was learned from the retrieved objects. Instead of listing all matches, the LLM identifies the most relevant ones—such as `dbo.MarkovProcess2`—and explains their role in the system. It also highlights key distinctions (for example, computing results into a session-scoped table rather than persisting them).

This output is not just an answer—it is a **compressed representation of reasoning**. It captures:

* what the user is trying to do,
* what objects are relevant,
* and why those objects matter.

This summary is then used to build the **rolling context** (shown in the Context tab), allowing subsequent prompts to build on prior work without repeating the entire process. In effect, the Answer tab acts as the bridge between one step of analysis and the next, turning a single query into part of a larger workflow.



![Figure 3 – Initial Opening](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/context_window.png)

*Figure 3 – Context window.*


## Filtering Object Types Before Retrieval

Figure 4 shows an attempt to improve retrieval accuracy by enabling **Filter ObjectTypes first (5)**. When this option is selected, the system makes an initial LLM call *before* querying Qdrant. The purpose of this call is to determine which types of objects are most relevant to the user’s prompt.

Instead of searching across all object types (tables, columns, stored procedures, LLM prompts, etc.), the LLM analyzes the prompt and returns a focused set of categories—for example:

* `SQL_STORED_PROCEDURE`
* `SQL_INLINE_TABLE_VALUED_FUNCTION`

These object types are then applied as a filter in the Qdrant query, which narrows the search space and increases the likelihood that the returned results are directly actionable. In this case, the results are more tightly focused on executable database objects involved in computing Markov models, rather than including explanatory tutorial content or loosely related metadata.

The benefit of this approach is improved precision. By constraining the embedding search to a smaller, more relevant subset of objects, the system reduces noise and increases the relevance of the top matches.

The trade-off is that this introduces an additional LLM call:

* It consumes extra tokens
* It adds latency before retrieval begins
* It may not always be necessary, especially when the embedding search alone already produces good results

As a result, this option is disabled by default and is best used when:

* the initial results are too broad or noisy, or
* the user has a strong expectation about the type of object they are looking for (e.g., “a stored procedure,” “a function,” etc.)

Figure 4 illustrates that with this option enabled, the retrieved objects are more consistently aligned with the expected execution layer of the system, improving the usefulness of the results for tasks such as identifying the correct procedure to run.

![Figure 4 – Filter objects by type](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/filter_object_types.png)

*Figure 4 – Filter objects by type.*


## Loading and Viewing Linked Content

Figure 5 demonstrates how to explore supporting documentation directly from the retrieved results. After selecting an item in **Retrieved Objects (1)**, any associated links are extracted and displayed in the **Linked URL dropdown (2)**.

Clicking **Load Link (3)** retrieves the content from the selected URL—typically a GitHub markdown file or blog page—and displays it in the **Link Contents tab**. This allows you to review detailed explanations, examples, or tutorials without leaving the application.

This step is particularly useful when the retrieved object is an **LLM prompt or tutorial**, as it provides deeper context beyond the metadata shown in the Selected Item panel. In this example, the selected item links to a tutorial on creating or updating a Markov model, and the full markdown content is loaded for inspection.

Alternatively, the **Copy URL** button can be used to open the link externally in a browser. While opening directly in a browser might provide a richer viewing experience, loading the content inside the application keeps the workflow self-contained and allows the material to be used alongside the current context and results.

This capability reinforces the idea of the workbench as a unified environment—combining retrieval, explanation, and reference material in a single interface.


![Figure 5 – Load linked URL](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/load_link.png)

*Figure 5 - load linked URL for deeper dive.*



## Figure 6 – Increasing the Retrieval Count

Figure 6 shows the effect of increasing the **Top N ** value, which controls how many objects are retrieved from Qdrant. By raising this number, the system casts a wider net in the embedding space, increasing the likelihood that the correct object appears somewhere in the results.

This is particularly useful when the initial retrieval does not surface the expected object. Common reasons for this include:

* The prompt uses **different terminology** than the metadata (e.g., “compute” vs. “generate” vs. “build”)
* The embedding model does not strongly associate the phrasing with the correct object
* The relevant object has a **sparse or generic description**
* The signal is diluted by **similar but more frequently occurring patterns**
* The prompt is **too short or ambiguous**, providing limited semantic guidance
* The correct object exists but is **ranked just outside the default Top N**
* Multiple concepts are combined in the prompt, weakening the embedding match

By increasing the retrieval count, these edge cases are mitigated because more candidates are available for downstream analysis.

However, this comes with trade-offs:

* **More tokens sent to the LLM**
  Each retrieved object contributes metadata (description, utilization, parameters, etc.) to the prompt context.

* **Increased noise**
  Additional objects may be less relevant, making it harder for the LLM to focus on the most important ones.

* **Longer response time and higher cost**
  Larger context windows require more processing.

Even for LLMs, more information is not always better—**a smaller, more precise context is generally preferable**.

In practice, increasing Top N is most useful as a fallback strategy when:

* the correct object is not appearing in the initial results, or
* the prompt is exploratory and you want broader coverage of the system.

Figure 6 illustrates how expanding the retrieval set surfaces additional candidates, improving recall at the expense of precision.


![Figure 6 – Higher Retrieval Count](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/higher_retrieval_count.png)

*Figure 6 - Higher retrieval count for better odds of finding the right embedding.*


## Figure 7 – Retrieval Without LLM Summarization

Figure 7 shows the system with **Use LLM (2)** disabled. In this mode, the application does not call a frontier model (such as OpenAI or Grok) after retrieving results from Qdrant.

Instead, the workflow stops at retrieval:

* The prompt is embedded and used to search Qdrant
* The top matches are displayed in **Retrieved Objects (5)**
* Selecting an item still populates the **Selected Item** panel
* Linked content can still be accessed via **Load Link (6)**

The key difference is that no synthesized explanation is generated in the **Answer tab**. The system behaves more like a **semantic search tool**, returning ranked matches without interpretation.

This mode has several advantages:

* **Faster response time** – no additional LLM call
* **Lower cost** – no token usage for summarization
* **Deterministic behavior** – results are purely based on embedding similarity

However, the trade-off is that the user must interpret the results manually. The system does not:

* explain why an object is relevant
* compare alternatives
* synthesize a coherent answer

As shown in Figure 7, even without the LLM, the workflow remains useful. You can still:

* identify relevant objects
* inspect metadata
* and load linked documentation directly

This makes the mode particularly valuable when:

* cost or latency is a concern, or
* the user prefers to work directly with raw results

In practice, this option turns the application into a fast, local-first discovery tool, while still preserving the ability to drill into documentation through linked content.


![Figure 7 – No Frontier Model](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/no_frontier_model.png)

*Figure 7 - No utilization of frontier model, to save token costs.*



## Executing SQL Directly

Figure 8 shows the system operating in **SQL execution mode**. In this case, a SQL query is entered directly into the **Prompt Input Box (1)**, and **Prompt is SQL (2)** is enabled.

When this option is selected, the normal AI workflow is bypassed. Instead of:

* embedding the prompt,
* retrieving objects from Qdrant, and
* invoking the LLM for interpretation,

the system sends the query directly to the SQL Server database for execution.

The results are returned and displayed in the **Query Results tab (3)** as a structured table. In this example, a simple query against `vwEventsFact` returns rows from the event dataset, including fields such as `CaseID`, `Event`, and `EventDate`.

This mode is useful when:

* the user already knows the exact query they want to run,
* they want to validate or inspect data directly, or
* they are transitioning from exploration to execution

Although the system still performs retrieval (as shown in **Retrieved Objects**), those results are not used to generate an answer. The focus is entirely on executing the provided SQL and returning the data.

In practice, this turns the workbench into a hybrid tool:

* an AI-assisted discovery environment when using natural language, and
* a direct query interface when working with SQL

This dual capability allows users to move seamlessly from understanding the system to interacting with it directly.


![Figure 8 – Run SQL](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/run_sql.png)

*Figure 8 - Run prompt as a SQL against TimeSolution.*



