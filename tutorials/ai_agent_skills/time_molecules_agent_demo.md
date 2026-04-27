

## Initial Opening – Control Overview


Figure 1 shows the initial opening of the Time Molecules AI-agent workbench. The numbered callouts highlight the key controls and interface elements that support the workflow, from prompt entry and Qdrant retrieval to LLM reasoning, SQL execution, and context management. The list below briefly describes each numbered component and its role in guiding the interaction.


![Figure 1 – Initial Opening](https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/ai_agent_skills/images/initial_opening.png)
*Figure 1 – Initial opening of the Time Molecules AI-agent workbench.*

1. **Qdrant / Backend Status**   Displays the active Qdrant collection along with the current chat and embedding backends. Useful for confirming you are querying the expected index and models.

2. **Prompt Input Box**   The main text area where you enter a natural language question or SQL statement (if SQL mode is enabled).

3. **Ask Button**   Submits the prompt and initiates the workflow: embedding → metadata retrieval → LLM reasoning → optional SQL execution.

4. **Results Limit**   Controls how many top matches are retrieved from Qdrant. Higher values increase context but may add noise.

5. **Use LLM Checkbox**   When enabled, the LLM synthesizes a final answer from retrieved metadata. When disabled, only raw retrieval results are shown.

6. **Filter ObjectTypes First**   Uses an LLM classifier to narrow the Qdrant search to relevant object types (e.g., tables, procedures, prompts), improving precision.

7. **Prompt is SQL**   Treats the input as a SQL query and executes it directly, bypassing LLM interpretation.

8. **Status Bar**   Displays the current stage of processing (e.g., searching Qdrant, waiting for LLM, executing SQL, errors).

9. **Progress Spinner**   Indicates active processing during LLM calls or long-running operations.

10. **Context Size Control**    Sets the maximum size (in characters) for the rolling context summary maintained by the workbench. A value of 0 disables context updates.

11. **Clear Context Button**    Resets the current working context summary, allowing you to start a new line of inquiry.

12. **Retrieved Objects (Top Hits)**    Displays ranked metadata matches from Qdrant, including object names, types, and similarity scores.

13. **Selected Item Details**    Shows detailed information for the selected hit, including description, utilization, parameters, sample code, and links.

14. **Load Linked Content**    Fetches and displays content from trusted links (GitHub or approved domains) associated with the selected item.

15. **Generate Sample SQL**
    Generates and optionally executes a basic SQL query for selected tables or columns.

16. **Results Tabs (Answer / Query Results / Context)**

* **Answer:** LLM-generated explanation or response
* **Query Results:** Tabular output from executed SQL
* **Context:** Rolling summary of the current session’s purpose, findings, and state

---


## Initial Run with Defaults


![Figure 2 – Initial Run](https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/ai_agent_skills/images/initial_run.png)

*Figure 2 – The result after pressing Ask using the sample prompt.*


After entering a prompt in the **Prompt Input Box (2)** and pressing **Ask (3)**, the system begins by embedding the prompt and retrieving the top matches from Qdrant, shown in **Retrieved Objects (12)**. As each stage progresses, the **Status Bar (8)** updates (e.g., searching Qdrant, waiting for the LLM), and the **Progress Spinner (9)** indicates active processing.

If **Use LLM (5)** is enabled, the retrieved metadata is then passed to the LLM, which generates a synthesized response displayed in the **Answer tab (16)**. If relevant SQL is inferred, it may be executed and displayed in the **Query Results tab (16)**. Selecting any item in **Retrieved Objects (12)** populates **Selected Item Details (13)**, where you can inspect descriptions, utilization, parameters, and sample code, or use actions like **Generate Sample SQL (15)**.

At the same time, the workbench reconstructs a rolling context summary (if **Context Size (10)** is greater than zero), which is displayed in the **Context tab (16)**. This summary captures the purpose of the query, key findings, and next steps, allowing subsequent prompts to build on prior work without replaying the full interaction history.


![Figure 3 – Initial Opening](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/context_window.png)

*Figure 3 – Context window.*

![Figure 4 – Filter objects by type](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/filter_object_types.png)

*Figure 4 – Filter objects by type.*

![Figure 5 – Load linked URL](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/load_link.png)

*Figure 5 - load linked URL for deeper dive.*

![Figure 6 – Higher Retrieval Count](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/higher_retrieval_count.png)

*Figure 6 - Higher retrieval count for better odds of finding the right embedding.*

![Figure 7 – No Frontier Model](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/no_frontier_model.png)

*Figure 7 - No utilization of frontier model, to save token costs.*


![Figure 8 – Run SQL](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/ai_agent_skills/images/run_sql.png)

*Figure 8 - Run prompt as a SQL against TimeSolution.*



