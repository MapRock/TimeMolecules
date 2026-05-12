# Time Molecules: Refresh and Major Update

Since the publication of [*Time Molecules*](https://technicspub.com/time-molecules/), May 2025, I have continued developing the ideas, the implementation, and the supporting material around it. This is not a new edition of the book, but it is more than minor cleanup. It is a meaningful refresh and expansion of the surrounding body of work.

The impetus for this refresh began when my work reached a point where I needed to pull everything together. See [An interlude before the 3rd Act of the Assemblage-of-AI](https://eugeneasahara.com/2026/02/17/an-interlude-before-the-third-act-of-the-assemblage-of-ai/) around mid February, 2026.

For a more "user-friendly" explanation of this Refresh, please see my blog announcing it: [Time Molecules 2026 Refresh](https://eugeneasahara.com/2026/05/02/time-molecules-2026-refresh/)

> **Note:** This refresh is set for launch on **May 13, 2026**.

## What has changed

### Clearer framing

One of the biggest improvements (well ... hopefully) is the overall conceptual clarity. I have become more explicit that businesses are made not only of facts about things, but also of stories in the form of event sequences. A customer journey, hospital visit, support incident, machine workflow, or AI agent execution is a story unfolding through time. In this framing, Markov models are abstractions of those stories.

That idea helps explain why Time Molecules matters. It's the time-side of BI. OLAP cubes aggregate facts about things, Time Molecules aggregates stories about processes.

## Beyond Single Markov Chains: Time Molecules as Enterprise Data Integration

Most people hear the words “Markov models” and immediately picture a single probabilistic chain describing one isolated process. That is **not** what Time Molecules is about.

Time Molecules is fundamentally an **enterprise-scale data integration framework** built for the age of event streams, AI agents, IoT, and process-aware intelligence. It treats every business outcome — a customer journey, hospital episode, support ticket, manufacturing run, or AI-agent execution — as a *story* told through sequences of timestamped events (cases). These stories are then compressed into a massive, multi-dimensional collection of Hidden Markov Models (HMMs) that can be sliced, diced, compared, and queried at scale — exactly the way OLAP cubes handle facts about *things*.

### Five Core Pillars of Time Molecules

Time Molecules is not a single-process Markov model tool. It is a complete enterprise data integration and process-intelligence framework. Its power comes from these five interlocking pillars, drawn directly from the real-world needs of BI, process mining, systems thinking, and AI-agent observability.

1. **Time is the Ubiquitous Dimension**  
   Time is the one attribute shared by virtually every system, log, sensor feed, and agent trace. By anchoring everything to timestamps and grouping events into cases, Time Molecules links processes across heterogeneous systems without requiring perfect upfront entity resolution or rigid global schemas. This creates a true “space-time” view of the enterprise.

2. **LLMs Play a Fundamental Role in Semantic Integration**  
   LLMs are the critical translation layer that makes large-scale integration practical in the messy real world. They discover and normalize event sets, map equivalent case types, extract events from unstructured sources, and support context engineering for AI agents — turning raw chaos into coherent, queryable process memory.

3. **Stories (Event Sequences / Cases) Are the Fundamental Transactional Unit of Intelligence**  
   Traditional BI works with *facts about things*. Time Molecules works with *stories that unfold over time*. Every customer journey, hospital episode, support ticket, manufacturing run, or AI-agent execution is a case — a sequence of timestamped events. These stories, not isolated facts, are the atomic unit of process-aware intelligence.

4. **Time Molecules Are the Time-Oriented Counterpart to Thing-Oriented OLAP Cubes**  
   Just as OLAP cubes compress millions-to-trillions of transactions into multi-dimensional aggregates of *things*, Time Molecules compresses millions-to-trillions of event sequences into a massive collection of lightweight, cacheable Hidden Markov Models (HMMs). The result is a probabilistic, multi-dimensional “process cube” that can be sliced, diced, compared, and queried at enterprise scale — in O(n) time.

5. **Process-Aware Intelligence via Integration with Enterprise Intelligence**  
   Time Molecules does not stand alone. It extends the *Tuple Correlation Web* from *Enterprise Intelligence* to create a full space-time web of knowledge: the BI side of process mining and systems thinking. This integration enables true executive function — comparing processes, spotting emerging patterns, aligning actions with competing goals, and giving both humans and AI agents the process memory they need to reason, plan, and adapt.

### Why This Matters (and Why It’s Not “Just Markov Chains”)

Time Molecules produces a web of linked Hidden Markov Models across a highly multi-dimensional space — the *time-oriented counterpart* to traditional thing-oriented OLAP cubes. It bridges Business Intelligence, Process Mining, and Systems Thinking, turning millions-to-trillions of event sequences into lightweight, cacheable, O(n) probabilistic abstractions that humans and AI agents can actually reason with.

It is not about replacing neural networks or claiming Markov chains are magically new. It is about building scalable, transparent, process-aware intelligence grounded in the real flows of your enterprise data — with time as the universal connector and LLMs as the indispensable translator.

This framing is what lets Time Molecules serve as process-aware memory and observability for the coming wave of AI agents while remaining fully compatible with the Enterprise Knowledge Graph work in *Enterprise Intelligence*.

## Expanded companion material

The book already contains tutorials and simple examples, and that remains an important part of its value. Since publication, I have expanded the GitHub companion material to further support the book with additional tutorials, examples, clarifications, and implementation details. The dev environment for the samples is in the doc, [install_timemolecules_dev_env.md](https://github.com/MapRock/TimeMolecules/blob/main/docs/install_timemolecules_dev_env.md), and code is found under [book_code](https://github.com/MapRock/TimeMolecules/tree/main/book_code).

The GitHub new material is meant to extend and reinforce the book, not replace it. The book lays out the larger framework and the core ideas in a structured way. The newer companion material helps readers go deeper into particular patterns, examples, and implementation directions.

Some of the stronger areas now include:

- [tutorials on the fundamental importance of Markov models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/fundamental_importance_of_markov_models)
- [comparing event transitions to understand why one branch differs from another](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/compare_event_transitions)
- [linking cases across systems or process types](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases)
- [dicing Markov models by time and other dimensions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models)
- [tutorials and supporting material around AI-agent usage](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills)

Together, the book and the expanded companion material make the work more teachable and more concrete than it was at launch.

## Stronger AI-agent relevance

The primary goal of this AI-agent feature is to have fitted this repo with the capability of answering questions a consumer AI agent would have about Time Molecules. That mechanism is summarized in this repo's [readme.md under "Information for AI Agents"](https://github.com/MapRock/TimeMolecules/blob/main/README.md).

Since the book came out, the industry has moved much more visibly toward AI agents, orchestration, observability, and process-aware context. That shift makes Time Molecules feel more timely.

I have done more work to explain how Time Molecules can serve as process-aware memory and analysis for AI-agent activity. Each agent run is a case. Each prompt, tool call, retry, approval, and failure is an event. Across many runs, those become stories that can be studied, compared, and abstracted into Markov models.

That gives Time Molecules a more immediate connection to where enterprise AI appears to be going.

See [AI Agent Skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills)

### Closer to larger-scale architecture

TimeSolution was originally meant as a demonstration system that was relatively approachable to install and study, especially on SQL Server. I still view it that way.

At the same time, I have put real effort into moving parts of the implementation closer to retrofit toward MPP-style platforms. The operative word is *closer*. This is not a claim that the work is now a finished production MPP product. It is a claim that the design and implementation have been pushed further in that direction than they were before.

That includes rethinking patterns that were too tied to one platform and improving the path toward broader-scale deployment ideas

See [sp_SelectEvents retrofit](https://github.com/MapRock/TimeMolecules/blob/main/docs/Spring_2026_Update/sp_Selected_Events_MPP_refactor_20206_04.md)

### Better explanation of process-aware intelligence

The surrounding blog material has also improved the explanation of the deeper intuition behind the work:

- stories as the transactional unit of human-level intelligence
- event sequences as the basis of process memory
- Markov models as abstractions of many related stories
- Time Molecules as the time-oriented counterpart to thing-oriented OLAP cubes
- strategy maps, competing goals, and performance management as a way to move from observer toward executive function

These explanations make the larger vision easier to understand than it was when the book first appeared.

See [Fundamental Importance of Markov Models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/fundamental_importance_of_markov_models)

## Why this matters

This refresh does not replace the book. It strengthens and extends it.

The original publication laid out the core ideas, examples, and tutorials. The work since then has made those ideas clearer, expanded the companion material, made the framework more relevant to AI agents, and pushed parts of the implementation somewhat closer to larger-scale practical architecture.

If there is a single sentence that best captures the refresh, it is probably this:

**Time Molecules is about making stories in the form of event sequences analyzable at scale, and using Markov models as abstractions of those stories.**

## No High-End User Interface for Time Molecules (Markov Models & Bayesian Conditional Probabilities)

One area that is intentionally **not** covered in the current 2026 refresh of Time Molecules is a polished, high-end graphical front-end UI. The refresh (and the accompanying demo application) deliberately focuses on the backend foundation and on serving as a **workbench** for assessing how AI agents can discover, query, and reason over the Time Molecules structures. In other words, the demo app is not intended as a production end-user dashboard; it is a testing harness that lets AI agents explore the SQL-based artifacts directly. My own day-to-day work has centered on SSMS (SQL Server Management Studio) as the primary interface because it gives full, transparent access to the stored procedures, table-valued functions, and views that power everything.

The good news is that this SQL-centric design already makes high-end visualization straightforward and powerful. Nearly every function in Time Molecules — including the Markov-model generators and the Bayesian/conditional-probability routines — returns clean, tabular result sets that behave exactly like ordinary dataframes. That means the outputs (Markov transition tables of the form *eventA → eventB*, probability, count, confidence, etc., and Bayesian conditional probability tables) can be consumed directly by modern business-intelligence tools.

**Yes — both Power BI and Tableau can connect to and execute stored procedures in addition to views.**  
- In Power BI you use the SQL Server connector and simply supply an `EXEC` statement (or a stored-proc call with parameters) in the Advanced Options; it works beautifully in Import or DirectQuery mode.  
- Tableau has even stronger native support: stored procedures appear directly in the data-source pane, can be dragged onto the canvas, and support parameters automatically.

This gives you an immediate high-end UI today without writing a single line of new front-end code:
- **Markov models** → heatmaps, Sankey diagrams, network graphs, or animated state-transition flows that show how one event leads to the next (with probabilities and confidence bands).  
- **Bayesian conditional probabilities** → interactive what-if slicers, parameterized reports, and dynamic dashboards where a user (or an AI agent) can slice by context (“given this weather, count, video tell, fatigue level…”) and instantly see the updated outcome probabilities.

In short, the current refresh deliberately stops at the robust, queryable SQL layer so that the heavy lifting stays close to the data (exactly as the “time-oriented counterpart to OLAP cubes” philosophy intends). A beautiful, purpose-built graphical UI with real-time Markov flows, hidden-state explorers, and scenario-modeling canvases is a logical **future** enhancement — but you already have a production-grade analytical surface available right now through any standard BI tool that can talk to SQL Server.

For alternative view possibilities, see [Bayesian Prolog](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/bayesian_prolog) and [Markov Model Graph Formats](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/markov_outputs_graph_format).

## Known Issues

Following are known issues that will be addressed over the next few weeks.

- [Bitmap access and deny security mechanism](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_security/accessbitmap_inheritance_path.md) isn't fully implemented - The sample database isn't intended to be up to enterprise quality plug and play. But carefully completing the implementation is still a step towards that goal.

## Selected companion material

**✅ Here are clean one-sentence summaries** for each tutorial folder:

### Selected Sampling of the Major GitHub Tutorials

- **[Fundamental importance of Markov models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/fundamental_importance_of_markov_models)**: This tutorial explains the fundamental importance of Markov models in TimeMolecules as compact abstractions that turn recurring event sequences (“stories”) into probabilistic models of typical process behavior.

- **[Compare event transitions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/compare_event_transitions)**: This tutorial shows how to compare the properties of destination events reached via competing transitions from the same source event in a Markov model.

- **[Link cases](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases)**: This tutorial demonstrates practical methods for discovering and linking related cases (including subprocesses) by matching shared properties and semantically similar events.

- **[Diced Markov models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models)**: This tutorial explains how to create “diced” (sliced) Markov models broken down by date or other dimensions to enable time-based or segmented comparison of process behavior.

- **[AI agent skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills)**: This tutorial presents the TimeMolecules AI Agent demo — a practical RAG-based agent that uses vector search to give grounded, intelligent answers across the entire knowledge base.

- **[Pre-aggregated Markov Models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/preaggregate_markov_models)**: This tutorial teaches how to pre-create and persist Markov models for common parameter combinations (analogous to OLAP pre-aggregations) to reduce query-time computation and improve performance.

You can drop this list straight into the root README or a central “Tutorials” page. Let me know if you want them shorter, longer, or reworded!

#### About the TimeMolecules AI Agent Demo

This application [AI agent skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills) is an example of how to accommodate AI agents by giving them semantic search access to the full TimeMolecules knowledge base (LLM prompts, tutorials, skills, and documentation). It addresses how the substantial material pulls together in the age of AI agents.

It also functions as my personal workbench. I actively use it to evaluate how well the entire site can answer an AI agent’s questions about Time Molecules — helping me identify gaps and improve the quality, clarity, and discoverability of the material.

### Related blog themes
- [Process-aware intelligence — *From Data through Wisdom: The Case for Process-Aware Intelligence*](https://eugeneasahara.com/2025/05/30/from-data-through-wisdom-the-case-for-process-aware-intelligence/)
- [Stories as the transactional unit of human-level intelligence — *Stories are the Transactional Unit of Human-Level Intelligence*](https://eugeneasahara.com/2025/10/10/stories-the-unit-of-human-level-intelligence/)
- [AI agents and context engineering — *AI Agents, Context Engineering, and Time Molecules*](https://eugeneasahara.com/2026/03/10/ai-agents-context-engineering-and-time-molecules/)
- [Planning, competing goals, and executive function — *The Complex Game of Planning*](https://eugeneasahara.com/2025/12/19/the-complex-game-of-planning/)
