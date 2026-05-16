
# Bayesian Probabilities in Time Molecules

## Purpose

This tutorial explains how Bayesian-style probabilities fit into Time Molecules.

In Time Molecules, Markov models answer questions like:

```text
Given this event, what usually happens next?
````

Bayesian probabilities answer a related but more flexible question:

```text
Given that this event or sequence occurred, how likely is another event or sequence?
```

The current TimeSolution implementation is closer to conditional probability than a full Bayesian framework with dynamically updated priors. However, the feature is still useful because it measures the strength of relationships between event sequences and stores those relationships for reuse. The book describes this as a practical way to reason under uncertainty by measuring how one sequence of events changes the likelihood of another. 

---

## Why this matters

A Time Molecules event stream is not just a record of what happened. It is a source of patterns.

Some patterns are sequential:

```text
arrive -> greeted -> seated -> ordered
```

Some patterns are conditional:

```text
If arrive happened, how often did drinks happen?
```

Some patterns are outcome-oriented:

```text
If greeted, seated, and intro happened, how often did bigtip happen?
```

Bayesian probabilities help measure these relationships.

That means they can support questions such as:

| Question                                                                                                     | Meaning                           |
| ------------------------------------------------------------------------------------------------------------ | --------------------------------- |
| Given that a customer arrived, how often were they offered drinks?                                           | Simple event-to-event probability |
| Given that a customer was greeted and seated, how often did they order?                                      | Sequence-to-event probability     |
| Given that a customer was greeted, seated, and introduced to the server, how often did they leave a big tip? | Sequence-to-outcome probability   |
| Given that a machine overheated, how often did a failure follow?                                             | Operational risk probability      |
| Given that a patient had triage and lab work, how often did imaging follow?                                  | Clinical workflow probability     |

This is important because many business questions are not just about the next step. They are about the probability of one meaningful pattern given another meaningful pattern.

---

## Conditional probability versus Bayesian probability

Strictly speaking, the current TimeSolution feature calculates conditional probabilities.

For example:

```text
P(B | A)
```

means:

```text
the probability of B given that A occurred
```

A full Bayesian system would also update prior beliefs as new evidence arrives. The book is careful about this distinction: the implementation focuses on calculating conditional probabilities, while still using the broader Bayesian framing because the goal is reasoning under uncertainty and measuring how evidence changes expectations. 

So the practical interpretation is:

> TimeSolution currently calculates Bayesian-style conditional probabilities between event sequences.

That is still valuable. It gives the system a reusable score for how strongly two sequences are associated.

---

## The basic idea

Suppose we want to know:

```text
Given that a customer arrived, what is the probability that drinks occurred?
```

In TimeSolution terms:

| Role       | Value             |
| ---------- | ----------------- |
| Sequence A | `arrive`          |
| Sequence B | `drinks`          |
| Event set  | `restaurantguest` |

The question becomes:

```text
P(drinks | arrive)
```

or:

```text
Of the cases where arrive occurred, how many also had drinks?
```

The book example shows `arrive` occurring 10 times, `drinks` occurring 7 times, and both occurring together 7 times. The resulting probability is 70%. 

---

## Basic example

```sql id="a86pfl"
SELECT *
FROM dbo.BayesianProbability(
    'arrive',           -- Sequence A: one-event sequence
    'drinks',           -- Sequence B: one-event sequence
    'restaurantguest',  -- Event set
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
```

This asks:

```text
Given arrive, what is the probability of drinks?
```

The important point is that the first two parameters are sequences, not merely single events. A sequence can contain one event, or it can contain several events separated by commas.

---

## Sequence-to-sequence probability

The more interesting use case is not only event-to-event comparison. It is sequence-to-event or sequence-to-sequence comparison.

For example:

```text
Given greeted, seated, and intro, what is the probability of bigtip?
```

```sql id="zgx720"
SELECT *
FROM dbo.BayesianProbability(
    'greeted,seated,intro', -- Sequence A: three-event sequence
    'bigtip',               -- Sequence B: one-event sequence
    'restaurantguest',       -- Event set
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
```

This asks:

```text
P(bigtip | greeted,seated,intro)
```

The book example explains that this returned `0.125`, meaning one out of eight matching cases led to `bigtip`. 

This is the major conceptual difference from a simple Markov transition. The condition can be a meaningful story fragment, not just the immediately previous event.

---

## What the counts mean

The Bayesian probability calculation is based on counts.

A typical result includes values like:

| Value          | Meaning                                                                  |
| -------------- | ------------------------------------------------------------------------ |
| `ACount`       | Number of cases or groups where Sequence A occurred.                     |
| `BCount`       | Number of cases or groups where Sequence B occurred.                     |
| `A_Int_BCount` | Number of cases or groups where both Sequence A and Sequence B occurred. |
| `P(B\|A)`      | Probability of Sequence B given Sequence A.                              |
| `P(A\|B)`      | Probability of Sequence A given Sequence B.                              |

The exact column names may vary by implementation or procedure version, but the basic logic is:

```text id="d4n8az"
P(B | A) = count(A ∩ B) / count(A)
```

and:

```text id="ykp673"
P(A | B) = count(A ∩ B) / count(B)
```

These two probabilities are not the same.

For example, almost everyone who leaves a big tip may have been greeted, seated, and introduced to the server. But only a small percentage of people who were greeted, seated, and introduced may leave a big tip.

That means:

```text
P(greeted,seated,intro | bigtip)
```

can be high while:

```text
P(bigtip | greeted,seated,intro)
```

is low.

This distinction is important.

---

## Why sequences matter

A single event can be too weak to explain much.

For example:

```text
arrive
```

is a broad condition. Almost every restaurant case has an arrival event.

But a sequence such as:

```text
greeted,seated,intro
```

is more specific. It describes a pattern of service.

That makes it more useful for outcome analysis.

| Sequence A                | Sequence B   | Possible interpretation                                  |
| ------------------------- | ------------ | -------------------------------------------------------- |
| `arrive`                  | `drinks`     | How often does arrival lead to drinks?                   |
| `greeted,seated,intro`    | `bigtip`     | Does a complete early service pattern relate to tipping? |
| `complaint,manager_visit` | `discount`   | How often does escalation lead to a discount?            |
| `lab_ordered,blood_drawn` | `lab_posted` | How often does the lab workflow complete?                |
| `overheat,alarm`          | `shutdown`   | How often does a warning pattern lead to shutdown?       |

This is where Bayesian probabilities become process-aware. The condition is not just a dimension member. It is a fragment of a story.

---

## Relationship to Markov models

Markov models and Bayesian probabilities are related, but they answer different questions.

| Feature       | Markov model                                    | Bayesian probability                          |                        |
| ------------- | ----------------------------------------------- | --------------------------------------------- | ---------------------- |
| Main question | What tends to happen next?                      | How likely is B given A?                      |                        |
| Typical shape | Event transition                                | Sequence relationship                         |                        |
| Example       | `ordered -> served`                             | `P(bigtip                                     | greeted,seated,intro)` |
| Output        | Transition probabilities and segment statistics | Conditional probability between sequences     |                        |
| Primary use   | Process flow modeling                           | Relationship and outcome probability analysis |                        |

A Markov model is naturally about transitions:

```text
A -> B
```

A Bayesian probability can be about broader sequence relationships:

```text
A,B,C => X
```

The book points out that this Bayesian/conditional probability feature later connects with Markov models to support Hidden Markov Model-style reasoning. 

In Time Molecules terms:

> Markov models describe event-flow structure.
> Bayesian probabilities describe conditional relationships between event sequences.
> Together, they can support richer reasoning about hidden states and likely outcomes.

---

## Relationship to Hidden Markov Models

A Hidden Markov Model combines two kinds of probability:

| HMM component                        | Time Molecules analogue                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------ |
| Transition probabilities             | Markov model transitions                                                             |
| Emission / observation probabilities | Bayesian-style probabilities between observed sequences and inferred states/outcomes |

Time Molecules does not need to claim that every Bayesian probability row is a formal HMM emission probability. The practical point is simpler:

> Once Markov transitions and conditional sequence probabilities are both stored, the system can start reasoning about observed events, likely hidden states, and likely outcomes.

For example:

```text
Observed sequence:
greeted -> seated -> intro
```

may increase the probability of a hidden service-quality state:

```text
good_service
```

which may increase the probability of:

```text
bigtip
```

This is one of the reasons Bayesian probabilities belong in the Time Molecules model ecosystem rather than as a separate statistical side calculation.

---

## Persisting probabilities

The `BayesianProbabilities` table stores calculated sequence-given-sequence probabilities so they do not have to be recomputed each time.

The book describes this as similar to how Markov models are persisted in the Model Ensemble. Caching these probabilities saves compute and makes them available for reporting, dashboards, analysis, or integration with other workflows. 

Conceptually, each row stores something like:

| Column concept   | Meaning                                            |
| ---------------- | -------------------------------------------------- |
| Sequence A       | The condition sequence.                            |
| Sequence B       | The target sequence.                               |
| Event set        | The event vocabulary or process context.           |
| A count          | Number of groups where Sequence A occurred.        |
| B count          | Number of groups where Sequence B occurred.        |
| A ∩ B count      | Number of groups where both occurred.              |
| P(B|A)           | Probability of B given A.                          |
| P(A|B)           | Probability of A given B.                          |
| Group type       | Grouping level, such as case, day, month, or year. |
| Date metadata    | When the probability was created or updated.       |
| Anomaly metadata | Optional anomaly/category context.                 |

The important implementation idea is that a probability row becomes a reusable model object.

It is no longer just an ad hoc query result.

---

## Grouping type

The book notes that `BayesianProbabilities` supports grouping types such as:

```text
CASEID
DAY
MONTH
YEAR
```

This allows probabilities to be calculated at different grains. 

| Group type | Example question                                         |
| ---------- | -------------------------------------------------------- |
| `CASEID`   | In cases where A happened, how often did B also happen?  |
| `DAY`      | On days where A happened, how often did B also happen?   |
| `MONTH`    | In months where A happened, how often did B also happen? |
| `YEAR`     | In years where A happened, how often did B also happen?  |

This matters because the meaning of probability changes with grain.

For example:

```text
P(drinks | arrive) by CASEID
```

is about customer visits.

But:

```text
P(high_sales | promotion) by DAY
```

is about days.

The grouping level must match the business question.

---

## Case and event filters

Like Markov models, Bayesian probability calculations become more useful when filtered.

Examples:

```sql id="8vv4jp"
-- Conceptual example
SELECT *
FROM dbo.BayesianProbability(
    'greeted,seated,intro',
    'bigtip',
    'restaurantguest',
    NULL,
    NULL,
    NULL,
    N'{"LocationID":1}',
    NULL,
    NULL
);
```

This asks the same sequence question, but only within a filtered population.

Possible filters include:

| Filter type      | Example                                                          |
| ---------------- | ---------------------------------------------------------------- |
| Case properties  | Location, customer type, employee, store, device, patient cohort |
| Event properties | Event-specific status, value, code, reason, metric, observer     |
| Date range       | Before/after a change, month, quarter, year                      |
| Event set        | Specific process or story vocabulary                             |

This allows questions such as:

```text
Given greeted,seated,intro, what is the probability of bigtip at LocationID 1?
```

or:

```text
Given lab_ordered,blood_drawn, what is the probability of lab_posted for ER patients?
```

---

## How an AI agent should use Bayesian probabilities

An AI agent should treat Bayesian probabilities as reusable conditional relationships.

Good agent questions include:

| Agent question                                         | Tooling direction                                                |
| ------------------------------------------------------ | ---------------------------------------------------------------- |
| “What is the probability of B given A?”                | Use Bayesian probability function/procedure.                     |
| “Does this sequence make that outcome more likely?”    | Compare P(B|A) against baseline P(B).                            |
| “Which prior sequence best predicts this outcome?”     | Test multiple Sequence A candidates against the same Sequence B. |
| “Did this relationship change over time?”              | Calculate by day/month/year or compare date windows.             |
| “Is this relationship different by property?”          | Slice by case/event properties.                                  |
| “Can this probability support hidden-state reasoning?” | Combine with Markov transition context.                          |

An agent should not treat a high probability as proof of causation. It should treat it as a measured association worth investigating.

---

## Example interpretation

Suppose the system calculates:

| Sequence A             | Sequence B | ACount | BCount | A_Int_BCount | P(B given A) |
| ---------------------- | ---------- | -----: | -----: | -----------: | -----: |
| `greeted,seated,intro` | `bigtip`   |      8 |      3 |            1 |  0.125 |

The interpretation is:

```text
The sequence greeted,seated,intro occurred in 8 cases.
The outcome bigtip occurred in 3 cases.
Both occurred together in 1 case.
Therefore, the probability of bigtip given greeted,seated,intro is 1 / 8 = 0.125.
```

That does not mean the service introduction caused or prevented a big tip.

It means that, in this selected event set and filter context, the observed conditional probability was 12.5%.

The next step might be to compare against other conditions:

| Comparison  | Question                                    |                                        |
| ----------- | ------------------------------------------- | -------------------------------------- |
| `P(bigtip)` | What is the baseline probability of bigtip? |                                        |
| `P(bigtip   | intro)`                                     | Does intro alone matter?               |
| `P(bigtip   | complaint)`                                 | Does a complaint suppress big tips?    |
| `P(bigtip   | LocationID=1)`                              | Does location matter?                  |
| `P(bigtip   | EmployeeID=7)`                              | Does employee/service behavior matter? |

The Bayesian probability is a starting point for inquiry.

---

## Common mistakes

| Mistake                                                         | Correction                                                            |
| --------------------------------------------------------------- | --------------------------------------------------------------------- |
| Treating the result as causation                                | It is an association unless supported by additional causal evidence.  |
| Forgetting the grain                                            | `CASEID`, `DAY`, `MONTH`, and `YEAR` answer different questions.      |
| Treating Sequence A and Sequence B as only single events        | Both can be sequences.                                                |
| Ignoring baseline probability                                   | A conditional probability is more useful when compared to a baseline. |
| Mixing incompatible filters                                     | The population must match the question.                               |
| Forgetting date ranges                                          | Probabilities can change over time.                                   |
| Assuming BayesianProbability is a full Bayesian updating engine | The current implementation is closer to conditional probability.      |

---

## Why this belongs in Time Molecules

Time Molecules is about discovering and storing reusable time-oriented structures.

Markov models store transition structure.

Bayesian probabilities store conditional sequence relationships.

FFT models can store cyclical signal structure.

Together, these model types describe different aspects of how things unfold:

| Structure                | Captures                                       |
| ------------------------ | ---------------------------------------------- |
| Markov model             | Flow from event to event                       |
| Bayesian probability     | Relationship between one sequence and another  |
| FFT model                | Cycles inside a numeric signal                 |
| Correlation / similarity | Association between tuples, models, or signals |

Bayesian probabilities help Time Molecules move from “what happened next?” toward:

```text
Given this pattern, what else becomes more likely?
```

That is a major part of process-aware intelligence.

---

## Summary

Bayesian probabilities in Time Molecules calculate the probability of one event sequence given another event sequence.

The current implementation is best understood as Bayesian-style conditional probability:

```text
P(B | A)
```

where `A` and `B` may each be one event or a sequence of events.

The result is useful because it turns event history into reusable relationship knowledge:

```text
Given arrive, how often did drinks occur?
Given greeted,seated,intro, how often did bigtip occur?
Given lab_ordered,blood_drawn, how often did lab_posted occur?
```

The `BayesianProbabilities` table persists these results so they can be reused without recalculating them each time.

In the broader Time Molecules architecture, Bayesian probabilities complement Markov models. Markov models describe transition flow. Bayesian probabilities describe conditional relationships between meaningful sequences. Together, they support richer reasoning about outcomes, hidden states, anomalies, and process behavior.

