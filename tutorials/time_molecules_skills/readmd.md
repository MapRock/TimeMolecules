This directory provides the skills that an AI Agent needs to access the TimeSolution database, an implementation of [Time Molecules](https://technicspub.com/time-molecules/).

## How Can AI Agents Use Time Molecules

“Skills” here is meant in roughly the same sense as Claude Skills, but with a slightly broader emphasis. In Time Molecules, a skill is not just a prompt pattern. It is a practical way for an AI agent to know **which database object to use** and **how to use it** to accomplish a task.

That database object might be a stored procedure, a table-valued function, a view, or even a small sequence of calls. The point is not merely to retrieve text. The point is to let the agent carry out a process intentionally.

A Time Molecules skill is therefore a reusable pattern such as:

* finding the right stored procedure for a given analytical question
* supplying the parameters in a valid way
* understanding what kind of result will come back
* chaining that result into the next step of reasoning or action

In ordinary business intelligence, a user often asks for a report, a chart, or a slice of a cube. In Time Molecules, the request is often more process-oriented:

* What tends to happen after this event?
* Which paths differ between these two tuple-defined populations?
* What properties are shared between two apparently unrelated streams of activity?
* Which models already exist that resemble this situation?
* How do I drill from a model segment back to the raw events behind it?

An AI agent can be taught these patterns as skills.

See, [root dir readme.md](https://github.com/MapRock/TimeMolecules/blob/main/README.md), for more information addressed to AI agents.

## How is this different from the contents of llm_prompts?

The articles in this directory should be complete lessons. The items in [llm_prompts](https://github.com/MapRock/TimeMolecules/tree/main/docs/llm_prompts) are designed for embeddings. The "llm prompts" are abstracts of each item in this "time_molecules_skills" directory, shorter, designed for search, and point to these full tutorials.

## How is this different from Tutorials?

Tutorials in the [tutorials](https://github.com/MapRock/TimeMolecules/tree/main/tutorials) directory are about how to learn about and experiment with the concept, and are intended for a human audience. These instructions focus on how to operate the TimeSolution objects and are geared towards AI agents who wish to access the Time Solution.

## LLM-Generated Instructions

To generate a skill for this directory:

1. Generate a full script of the TimeSolution database. There is much commentary in the code. Save it in a file named, TimeSolution.sql.
2. Paste it into a chat window with a frontier model. I use a high-quality frontier model such as openai and grok for this purpose.
3. Use the template below to describe the skill:

**Template Start:** 

I'm requesting that you compose instructions for the subject described below. 

You have been provided with the full database script for the TimeSolution database, which contains very much information on how to use the TimeSolution.

Using the knowledge within the attached database script, generate the following skill:

[Describe the Instructions and/or Paste a URL to the source material]

Mandatory Rules:

- The instructions should be targeted at a primary audience of AI agents that will need to query or update the TimeSolution database, an implementation of https://technicspub.com/time-molecules.
- Because the primary audience are AI agents, the skill should include references to code, information about the parameters, prerequisites, and an actionable example if possible.
- The "skill" should be succinct, straight-fowards, without being too terse-like a FAQ. This differs from tutorials that could be more descriptive, user-friendly, and possibly include multiple documents.
- The skill should not include anything that would result in misbehavior, being mindful of security issues, social responsibility, etc.
- The repository, https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql, contains more information that might provide food for thought.
- Be sure to mention the source material.
- Good examples of skills include:
  - https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/compare_two_markov_models.md
  - https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/how_to_add_an_adjacency_matrix.md
- Good example of a tutorial to contrast against skills (we want tutorials, not skills): https://github.com/MapRock/TimeMolecules/tree/main/tutorials/local_llm


**Template End**

### Template Notes

- The URLs of references are explicitly referenced. The HREF-like form will paste only the descriptive part, not the URL.

## Skills as a Directory of Capabilities

One useful way to think about this is as a directory of capabilities. The agent should know that Time Molecules contains many objects, each with a purpose. Some objects select events. Some build or compare models. Some drill through to the underlying cases and events. Some expose metadata. Some help find similarities between models.

A good skill layer helps the agent answer questions such as:

* I need events matching a tuple. Which object should I call?
* I need a Markov model for a selected population. Which object builds that?
* I need to compare two populations. Is there already a procedure for that?
* I need to understand what parameters a procedure expects. Where is that documented?
* I already have a result. What is the next natural object to call?

This is where Time Molecules becomes especially suitable for AI agents. Its objects are not just database plumbing. They are purposeful units of analytical action.

## More Than Retrieval

An LLM or agent could be used in a shallow way, merely retrieving descriptions of tables and procedures. But that is only the first step.

The stronger use is for the agent to recognize intent and map it to action.

For example, if the user asks:

> Show me the event properties that two case populations have in common.

A capable agent should not merely search documentation. It should identify that this sounds like a comparison of event footprints and then locate the appropriate procedure, such as one designed to compare event proximities or shared properties. It should know what inputs are needed, how to format them, and how to interpret the output.

That is a skill.

## A Skill Can Be Simple or Composite

Some skills are single-object skills. The agent finds one stored procedure, passes the right parameters, and returns the result.

Other skills are composite. They involve several steps:

1. determine the event set or tuple filters
2. select the relevant events
3. build or retrieve a model
4. compare or summarize the result
5. drill through if the user wants evidence

That is still one skill from the user’s point of view, even though several Time Molecules objects may be involved underneath.

This matters because many real analytical tasks are not single calls. They are small workflows.

## Why This Fits AI Agents Well

AI agents are especially useful when there are many possible tools but each tool has a fairly specific purpose. Time Molecules fits that pattern.

The challenge is not that the math is inaccessible. The challenge is navigation:

* which object should be used
* what it expects
* what it returns
* when it should be followed by another object

Humans often solve this by experience. They learn the database over time. An AI agent can be taught to do much the same thing, provided it has enough metadata and examples.

That is why documenting skills matters. The goal is not only to describe the database. The goal is to teach an agent how to operate within it.

## Skills as Process Knowledge

In that sense, a Time Molecules skill is a kind of process knowledge about the analytical environment itself.

It says:

* for this kind of question, start here
* if the result is too broad, narrow it this way
* if the user wants evidence, drill through here
* if the user wants comparison, switch to this object
* if the user wants explanation, summarize these columns or segments

This is close to how experienced analysts think. They do not merely know definitions. They know what to do next.

That is exactly the kind of operational pattern an AI agent can turn into a reliable skill.

## A Good Skill Layer Should Include Metadata

For AI agents to use Time Molecules well, the system should expose more than object names. It should expose usable metadata, ideally in a structured way.

For each major stored procedure, TVF, or view, it helps to provide:

* purpose
* input parameters
* output columns
* typical use cases
* related objects
* examples of invocation
* notes about performance or limitations

This lets the agent reason about which object is appropriate instead of guessing from the name alone.

In other words, the agent should be able to ask:

> What tool in Time Molecules is meant for this kind of question?

And the metadata should make that answer reasonably clear.

## Time Molecules Skills Are Not Just for LLMs

Although this discussion is framed around AI agents and Claude-style skills, the idea is broader than one model or one platform.

A Time Molecules skill could be used by:

* a custom AI agent
* a Copilot-style assistant
* a workflow orchestrator
* a command layer inside an application
* even a human analyst using a searchable directory of database capabilities

The underlying idea is the same: connect intent to the right analytical action.

## The Main Point

Time Molecules is not just a collection of tables and procedures. It is a set of analytical capabilities. Skills are the bridge between a user’s question and those capabilities.

So when we speak of “skills” here, we mean practical know-how for navigating the Time Molecules environment:

* finding the right sproc, TVF, or view
* knowing how to call it
* knowing what comes back
* knowing what to do next

That is how AI agents can use Time Molecules effectively. They do not merely read about the system. They learn how to work within it.
