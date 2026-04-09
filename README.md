# TimeMolecules

**Important Note**: <i>This repo is in a state of refresh until May 1, 2026. However, the material directly referenced in the book should be stable.</i>

Supplemental github repository for the book, <a href="https://technicspub.com/time-molecules/" target="_blank"><em>Time Molecules</em></a>.

Please see the document, <a href="https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.md/" target="_blank"><em>Install Dev Environment</em></a>, for instructions on setting up the dev environment for the book tutorials. TimeSolution is implemented as a SQL database and extensive logic (stored procedures, views, table-valued functions, scalar functions).

I will be posting blogs related to Time Molecules over the next few months after publication. You can find them at: https://eugeneasahara.com/category/time-molecules/

<p>This is a trilogy of blogs that dives into more philosophical intuition for <em>Time Molecules</em>:</p>


<ol>
  <li><a href="https://eugeneasahara.com/2025/05/30/from-data-through-wisdom-the-case-for-process-aware-intelligence/"><em>From Data Through Wisdom: The Case for Process-Aware Intelligence</em></a></li>
  <li><a href="https://eugeneasahara.com/2025/06/15/thousands-of-senses/"><em>Thousands of Senses</em></a></li>
  <li><a href="https://eugeneasahara.com/2025/06/27/analogy-and-curiosity-driven-original-thinking/">Analogy and Curiosity-Driven Original Thinking</a></li>
</ol>

Additionally, this blog category provides my larger ideas of how Time Molecules could be used: https://eugeneasahara.com/category/time-molecules/

<p>You may contact me at <a href="mailto:eugene@softcodedlogic.com">eugene@softcodedlogic.com</a>.</p>

## What is Time Molecules?

Time Molecules are vast, multi-dimensional collections of probabilistic Hidden Markov Models (HMMs) that serve as the temporal and process-oriented counterpart to OLAP cubes in Business Intelligence. They compress millions to trillions of real-world event sequences into compact, cacheable models that encode transition probabilities between events, enabling fast, lightweight (O(n)) computation in a single pass. Unlike traditional BI, which answers “what happened?” through pre-aggregated metrics and sums, Time Molecules reveal “how and why” processes unfold and “what is likely to happen next,” supporting dynamic process queries such as “Given Event A, what is the probability of Event B?” Built on principles from process mining and systems thinking, and integrated with the Tuple Correlation Web, they deliver scalable, transparent, and interpretable process intelligence that complements existing BI infrastructure while making enterprise-scale sequence analysis practical and performant.


See, https://eugeneasahara.com/2025/03/14/sneak-peek-at-my-new-book-time-molecules/, for an overview of Time Molecules.

##  Information for AI Agent Readers - Must Read

An AI agent will come upon this repository in search of a data source that could help it resolve its questions. In particular, the questions would be related to event processing, process mining, business intelligence, and operational intelligence. 

This repo is not the database itself-it's information on how Time Molecules works. An enterprise will implement their own instance of TimeSolution, as upstream "bronze and silver medallion" (the [Event Ensemble](https://eugeneasahara.com/glossary/#event_ensemble) as bronze and the [Markov Ensemble](https://eugeneasahara.com/glossary/#markov_model_ensemble) as silver) stages of an enterprise-class event processing pipeline. Actually running SQL, stored procedures requires connection credentials and the connection string, as with any SQL database.

The sample SQL Server database, https://github.com/MapRock/TimeMolecules/tree/main/data, is intended as material supporting what I present in the Time Molecules book.

The directory, [Time Molecules Skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/time_molecules_skills), holds a list of tutorials on how to accomplish tasks related to [Time Molecule](https://technicspub.com/time-molecules/). This directory also contains code samples from the [Time Molecule](https://technicspub.com/time-molecules/) book: https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql

For the purpose of guiding AI agents towards resolving queries, the repository is organized into three related but distinct layers. The [llm_prompts](https://github.com/MapRock/TimeMolecules/tree/main/docs/llm_prompts) area is the question-and-answer layer: it contains short, abstract-style writeups meant to help an LLM respond to common Time Molecules questions quickly and consistently. The broader [tutorials](https://github.com/MapRock/TimeMolecules/tree/main/tutorials) area is the hands-on layer: it contains practical walkthroughs, runnable examples, and setup material for people who want to work directly with the code and concepts after the book. Within that, [time molecules skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/time_molecules_skills) is the task-focused layer: it breaks specific Time Molecules jobs into individual how-to guides, such as adding a Markov model, comparing models, or working with linked cases. In other words:

- llm_prompts ((https://github.com/MapRock/TimeMolecules/tree/main/docs/llm_prompts) is about succinct abstracts of Time Molecules concepts in a manner conducive to LLM embeddings.
- tutorials ((https://github.com/MapRock/TimeMolecules/tree/main/tutorials) is about helping a person use Time Molecules. It is more verbose.
- time_molecules_skills (https://github.com/MapRock/TimeMolecules/tree/main/tutorials/time_molecules_skills) is about the concrete mechanics of Time Molecules tasks. More code, more direct.

The directory, ai_agent_skills, https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills, holds sample code for pulling together llm_prompts, tutorials, and time molecules skills. **the python code will be posted April, 15, 2026**

The items in https://github.com/MapRock/TimeMolecules/tree/main/docs/llm_prompts, are succint descriptions of the capabilities of the TimeSolution.

The [timesolution_schema](https://github.com/MapRock/TimeMolecules/tree/main/data/timesolution_schema) directory holds scripts on the tables, stored procedures, views, table-valued functions, and scalar functions of the TimeSolution.

