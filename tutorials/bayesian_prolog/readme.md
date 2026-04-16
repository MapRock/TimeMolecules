# Contributing Markov Model Probabilities to a Common Prolog Language

This tutorial explains how to treat a Markov model as a **web of conditional beliefs** and export those beliefs into a Prolog-friendly common language that can live alongside ordinary boolean facts and rules. The practical goal is to let AI agents and human users query TimeSolution in a way that unifies:

* **measured, probabilistic knowledge** from event data and Markov models
* **objective, boolean knowledge** from rules, metadata, and explicit facts

The key intuition is simple: the world is always changing, therefore complex, therefore probabilistic. But it is not chaotic, so it is still logical. A Time Molecules Markov model captures that by storing transition probabilities between events; each segment can be interpreted as a conditional belief about what tends to happen next. The export step turns those segments into a symbolic form that can participate in Prolog reasoning. ([GitHub][1])

## Source material

This tutorial is based on the following materials:

* the Time Molecules tutorial code `export_modelevents_to_belief.py`, which exports rows from `dbo.ModelEvents` as Prolog belief facts; ([GitHub][1])
* the sample output file `model_123_beliefs.pl`, which shows the exported belief format; ([GitHub][2])
* the blog post *Prolog AI Agents – Prolog’s Role in the LLM Era, Part 2* , which describes combining current conditions from databases with model-derived rules and custom Prolog rules at query time; ([Soft Coded Logic][3])
* the `link_cases` tutorial, which demonstrates context expressed as property filters such as `LocationID=1` and `EmployeeID=1`; ([GitHub][4])
* the broader TimeMolecules repository, including `book_code/sql`, as supporting implementation context. ([GitHub][5])

## The idea

A row in `dbo.ModelEvents` is usually read as a Markov segment:

* given `EventA`
* the probability of `EventB`
* is `Prob`

The export script already treats that row as a belief and emits facts of the form:

```prolog
belief(hypothesis(EventB), evidence([EventA]), Prob).
```

For example, the sample output includes beliefs such as:

```prolog
belief(hypothesis(greeted), evidence([arrive]), 0.8).
belief(hypothesis(seated), evidence([arrive]), 0.1).
belief(hypothesis(depart), evidence([arrive]), 0.1).
```

That means the Markov model is being interpreted not merely as a matrix, but as a network of conditional beliefs about what follows what. ([GitHub][1])

That is the bridge to a common Prolog language.

Instead of treating probabilities and logic as separate worlds, we can express both symbolically:

* boolean rules and facts describe what is explicitly known
* belief facts describe what is measured and probabilistic
* both can be queried together

This matches the Part 2 blog’s idea that current conditions can be retrieved from databases, model rules can be brought in, and custom Prolog rules can be merged at query time. ([Soft Coded Logic][3])

## What the existing export does

The current exporter:

* connects to TimeSolution using environment variables for server and database;
* queries `dbo.ModelEvents` with `SELECT ModelID, EventA, EventB, Prob FROM dbo.ModelEvents WHERE ModelID = ?`;
* converts values into safe Prolog atoms;
* formats each row as `belief(hypothesis(EventB), evidence([EventA]), Prob).`; and
* writes the result either to stdout or to an output file. ([GitHub][1])

That is already useful, but it is only half the common language. It exports **beliefs about transitions**, but not yet the **context in which the model is valid**.

## The missing half: model context as facts

For a Time Molecules model to participate meaningfully in symbolic reasoning, an AI agent should know not just the segments, but also the model’s context. If a model was built for a slice like:

* `EmployeeID=1`
* `LocationID=1`

then those conditions should be exported as Prolog facts as well.

For this tutorial, we will write as if the exporter already includes that information in a form such as:

```prolog
belief_property(123, locationid, 1).
belief_property(123, employeeid, 1).
belief_property(123, metricid, time_between_events).
belief_property(123, order_n, 1).
belief_property(123, eventset, restaurant_demo).
```

That gives each model a symbolic context. It says: these beliefs are not floating in space; they belong to a particular slice of reality.

This is analogous to how the `link_cases` tutorial uses explicit JSON case filters such as `{"LocationID":1,"EmployeeID":1}` to define a concrete context for comparison. ([GitHub][6])

## Recommended common-language pattern

Use three kinds of symbolic material together.

### 1. Objective facts

These are the hard facts or metadata.

```prolog
case_property(case_11, locationid, 1).
case_property(case_11, employeeid, 1).
event_type(arrive).
event_type(greeted).
event_type(seated).
```

### 2. Model context facts

These say when a model applies.

```prolog
belief_property(123, locationid, 1).
belief_property(123, employeeid, 1).
belief_property(123, modelid, 123).
```

### 3. Belief facts from ModelEvents

These say what tends to happen next within that context.

```prolog
belief(123, hypothesis(greeted), evidence([arrive]), 0.8).
belief(123, hypothesis(seated), evidence([arrive]), 0.1).
belief(123, hypothesis(depart), evidence([arrive]), 0.1).
```

Notice one small extension here: adding the `ModelID` as the first argument to `belief/4`. The current sample file omits this and uses `belief/3`, but for an agent-friendly common language, including the model identifier makes the beliefs much easier to join to their context. That is a recommended refinement, not a claim about the current exporter. The current exporter emits `belief/3`. ([GitHub][1])

## Why this matters for AI agents

An AI agent working over TimeSolution should be able to answer questions like:

* What does employee 1 at location 1 usually do after `arrive`?
* Which next event is most strongly believed after `served` in this model?
* Under what context was this belief learned?
* Does the current case match the context of a known model closely enough to apply its beliefs?

That is much easier if everything is available in a common symbolic shape.

Without the common language, the agent has to jump between:

* SQL rows in `ModelEvents`
* SQL rows describing model context
* plain Prolog rules
* external prompt text

With the common language, those become one queryable layer.

## Suggested export format

A practical agent-facing export should look like this:

```prolog
% Model identity
belief_property(123, modelid, 123).

% Context
belief_property(123, locationid, 1).
belief_property(123, employeeid, 1).

% Transition beliefs
belief(123, hypothesis(greeted), evidence([arrive]), 0.8).
belief(123, hypothesis(seated), evidence([arrive]), 0.1).
belief(123, hypothesis(depart), evidence([arrive]), 0.1).
belief(123, hypothesis(intro), evidence([seated]), 0.8889).
belief(123, hypothesis(check), evidence([served]), 0.875).
```

This form supports three classes of agent behavior:

* retrieve beliefs for a matching context
* compare beliefs across contexts
* combine beliefs with boolean rules

## Example reasoning pattern

Suppose the current case has these facts:

```prolog
case_property(case_42, locationid, 1).
case_property(case_42, employeeid, 1).
current_event(case_42, arrive).
```

And the model export contains:

```prolog
belief_property(123, locationid, 1).
belief_property(123, employeeid, 1).
belief(123, hypothesis(greeted), evidence([arrive]), 0.8).
belief(123, hypothesis(seated), evidence([arrive]), 0.1).
belief(123, hypothesis(depart), evidence([arrive]), 0.1).
```

Then an agent can reason in ordinary boolean terms about model applicability:

```prolog
model_applies(ModelID, CaseID) :-
    belief_property(ModelID, locationid, V1),
    case_property(CaseID, locationid, V1),
    belief_property(ModelID, employeeid, V2),
    case_property(CaseID, employeeid, V2).
```

And separately retrieve the probabilistic beliefs for that applicable model.

The logic remains boolean. The belief remains probabilistic. They coexist.

## Recommended SQL-to-Prolog workflow

For an AI agent or developer, the workflow should be:

### Step 1: choose the model

Select a `ModelID` whose context matches the current question or case slice.

### Step 2: export the segments

Use the `export_modelevents_to_belief.py` pattern to pull the model’s rows from `dbo.ModelEvents` and emit belief facts. The current script already does this for `EventA`, `EventB`, and `Prob`. ([GitHub][1])

### Step 3: export the context

Also emit the model’s governing properties as `belief_property/3` facts. This tutorial assumes those properties are available from the model definition layer and should be exported alongside the segments.

### Step 4: load both into Prolog

Load the resulting `.pl` file into the agent’s symbolic reasoning environment.

### Step 5: combine with current facts

Bring in current case properties, event facts, or business rules from databases or rule files.

### Step 6: reason

Use boolean rules to decide whether a model applies, then use the belief facts as probabilistic guidance.

## Example tutorial code shape

An agent-oriented exporter should conceptually do two exports.

### A. Export beliefs

This already exists in the current script:

```python
SELECT ModelID, EventA, EventB, Prob
FROM dbo.ModelEvents
WHERE ModelID = ?
ORDER BY EventA, EventB
```

formatted into:

```prolog
belief(hypothesis(EventB), evidence([EventA]), Prob).
```

([GitHub][1])

### B. Export model properties

The extended exporter should also query the model’s slice properties and emit:

```prolog
belief_property(ModelID, PropertyName, PropertyValue).
```

For example:

```prolog
belief_property(123, locationid, 1).
belief_property(123, employeeid, 1).
```

This is the step that turns an isolated probability web into a context-aware symbolic object.

## How AI agents should use it

An AI agent should not blindly treat a model’s beliefs as universal truth.

It should:

* inspect `belief_property/3` to understand the model’s scope
* compare that scope to the current case or user query
* only then use the model’s belief edges as guidance

That matters ethically and operationally. A probability learned in one context should not automatically be projected into another. In practice, the same event pair can have different transition probabilities across employees, locations, dates, or case types.

## What this contributes to the common language

This approach contributes something important.

Boolean logic alone is too rigid for a changing world.
Probability alone is too weak to express explicit structure, constraints, and rules.

Together they give a better working language:

* **facts** say what is true
* **rules** say what follows logically
* **beliefs** say what tends to happen under uncertainty
* **belief properties** say when those beliefs apply

That is exactly the kind of common language needed when measured data and objective knowledge have to coexist.

## Good first experiments

For a small experiment, use a model like the sample one in `model_123_beliefs.pl`, where the restaurant-style transitions are easy to read. The sample includes beliefs such as `arrive -> greeted`, `seated -> intro`, and `served -> check`, which are intuitive enough to debug visually. ([GitHub][2])

Then add just two context facts, for example:

```prolog
belief_property(123, locationid, 1).
belief_property(123, employeeid, 1).
```

and write simple rules that test whether the model applies to a current case.

That is enough to validate the full pattern before making it more sophisticated.

## Safety and responsible use

AI agents should treat exported probabilities as **guidance**, not as determinate truth. They are summaries of observed process behavior, not guarantees about what must happen next. Agents should also avoid using such beliefs to make high-stakes decisions without human review, especially when the model context is incomplete, stale, or poorly matched to the case at hand.

The safe use pattern is:

* confirm context
* surface the belief and its probability
* explain that it is conditional and measured
* combine it with explicit rules and current facts
* keep a human in the loop for important decisions

## Summary

A Time Molecules Markov model can be read as a web of conditional beliefs, one segment at a time. The existing exporter already proves the idea by turning `dbo.ModelEvents` rows into Prolog belief facts. The next step is to export the model’s properties as context facts so that those beliefs can join a common Prolog language alongside objective facts and boolean rules. That gives AI agents a practical way to reason over a world that is always changing and therefore probabilistic, yet still structured enough to remain logical. ([GitHub][1])

[1]: https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/bayesian_prolog/export_modelevents_to_belief.py "raw.githubusercontent.com"
[2]: https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/bayesian_prolog/model_123_beliefs.pl "raw.githubusercontent.com"
[3]: https://eugeneasahara.com/2024/08/07/prologs-role-in-the-llm-era-part-2/ "Prolog AI Agents – Prolog’s Role in the LLM Era, Part 2 – Soft Coded Logic"
[4]: https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/link_cases/readme.md "raw.githubusercontent.com"
[5]: https://github.com/MapRock/TimeMolecules/tree/main/book_code/sql "TimeMolecules/book_code/sql at main · MapRock/TimeMolecules · GitHub"
[6]: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases "TimeMolecules/tutorials/link_cases at main · MapRock/TimeMolecules · GitHub"
