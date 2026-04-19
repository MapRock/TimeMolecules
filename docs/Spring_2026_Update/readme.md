# Time Molecules: Refresh and Major Update

Since the publication of [*Time Molecules*](https://technicspub.com/time-molecules/), I have continued developing the ideas, the implementation, and the supporting material around it. This is not a new edition of the book, but it is more than minor cleanup. It is a meaningful refresh and expansion of the surrounding body of work.

> **Note:** This refresh is set for launch on **May 1, 2026**.

## What has changed

### Clearer framing

One of the biggest improvements is conceptual clarity.

I have become more explicit that businesses are made not only of facts about things, but also of stories in the form of event sequences. A customer journey, hospital visit, support incident, machine workflow, or AI agent execution is a story unfolding through time. In this framing, Markov models are abstractions of those stories.

That idea helps explain why Time Molecules matters. OLAP cubes aggregate facts about things. Time Molecules aggregates stories about processes.

### Expanded companion material

The book already contains tutorials and practical examples, and that remains an important part of its value. Since publication, I have expanded the GitHub companion material to further support the book with additional tutorials, examples, clarifications, and implementation details.

The GitHub material is meant to extend and reinforce the book, not replace it. The book lays out the larger framework and the core ideas in a structured way. The newer companion material helps readers go deeper into particular patterns, examples, and implementation directions.

Some of the stronger areas now include:

- tutorials on the fundamental importance of Markov models
- comparing event transitions to understand why one branch differs from another
- linking cases across systems or process types
- dicing Markov models by time and other dimensions
- tutorials and supporting material around AI-agent usage

Together, the book and the expanded companion material make the work more teachable and more concrete than it was at launch.

### Stronger AI-agent relevance

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

## Selected companion material

### GitHub tutorials
- [Fundamental importance of Markov models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/fundamental_importance_of_markov_models)
- [Compare event transitions](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/compare_event_transitions)
- [Link cases](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases)
- [Diced Markov models](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/diced_markov_models)
- [AI agent skills](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/ai_agent_skills)

### Related blog themes
- [Process-aware intelligence — *From Data through Wisdom: The Case for Process-Aware Intelligence*](https://eugeneasahara.com/2025/05/30/from-data-through-wisdom-the-case-for-process-aware-intelligence/)
- [Stories as the transactional unit of human-level intelligence — *Stories are the Transactional Unit of Human-Level Intelligence*](https://eugeneasahara.com/2025/10/10/stories-the-unit-of-human-level-intelligence/)
- [AI agents and context engineering — *AI Agents, Context Engineering, and Time Molecules*](https://eugeneasahara.com/2026/03/10/ai-agents-context-engineering-and-time-molecules/)
- [Planning, competing goals, and executive function — *The Complex Game of Planning*](https://eugeneasahara.com/2025/12/19/the-complex-game-of-planning/)
