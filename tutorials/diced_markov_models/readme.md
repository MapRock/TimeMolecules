Sample scripts for how to create sets of Markov Models diced by date, property, etc.

## Dicing by date in the BI sense

Based on the sample, https://github.com/MapRock/TimeMolecules/blob/main/tutorials/diced_markov_models/diced_markov_models_by_date.sql

In Business Intelligence, *dicing* means taking the same basic subject of analysis and slicing it into many smaller, comparable subsets. In a sales cube, that might mean looking at sales by month, by region, or by product category. In Time Molecules, the idea is similar, but the thing being diced is not just a total or average. It is a **process model**.

For this example, the process is the `cardiology` event set, and the dice dimension is **time by month**. Instead of creating one large Markov model over a broad date range, the script creates a separate model for each month. Each monthly model uses the same core parameters such as event set, transforms, case logic, and metric, but changes the `StartDateTime` and `EndDateTime` to isolate one month at a time.

That is important because process behavior often changes over time. Clinical workflows, staffing patterns, patient mix, coding practices, and operational bottlenecks can all drift. A single model built across a very long span may blur together patterns that were actually different from month to month. By dicing the data by date, the models become easier to compare and more meaningful analytically.

This is also useful for performance. In TimeSolution, the date range is one of the most important parameters in many major functions. Narrower windows usually mean less data scanned, faster model creation, and more targeted analysis. In practice, many useful comparisons differ only by time. For example:

* this month versus last month
* quarter to date versus previous quarter
* rolling 30 days versus the prior rolling 30 days
* one month in a past year versus the same month this year

The script in this example demonstrates a general dicing pattern:

1. Build a driving set of date windows.
2. Treat each window as one slice of analysis.
3. Call `CreateUpdateMarkovProcess` once per slice.
4. Capture the resulting `ModelID` values for later comparison or downstream analysis.

diced_markov_models_by_date.sql dices only by month, the same pattern can be extended to other BI-style dimensions. You could dice by month and employee, month and location, or month and case property. In that sense, this example is the date-based version of a broader Time Molecules pattern: **hold most parameters constant, vary one dimension deliberately, and create comparable process models across the resulting slices.**

## A Bayesian way to read the final matrix

The last part of the script turns the monthly diced models into a matrix where each row is an `EventA -> EventB` transition and each column is a month. The cell value is the transition probability for that month. This is the output:

| Event1A | EventB | 2024-11 | 2024-10 | 2024-09 | 2024-08 | 2024-07 | 2024-06 | 2024-05 | 2024-04 | 2024-03 | 2024-02 | 2024-01 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Arrhythmia | Echo | 0.4957 | 0.4902 | 0.4989 | 0.4827 | 0.5076 | 0.4906 | 0.5085 | 0.5048 | 0.4953 | 0.4978 | 0.5120 |
| Arrhythmia | Holter Start | 0.5043 | 0.5098 | 0.5011 | 0.5173 | 0.4924 | 0.5094 | 0.4915 | 0.4952 | 0.5047 | 0.5022 | 0.4880 |
| Echo | Holter Start | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| Holter End | Holter Neg | 0.5053 | 0.5002 | 0.4964 | 0.4906 | 0.5046 | 0.5037 | 0.5087 | 0.5008 | 0.5101 | 0.4981 | 0.4885 |
| Holter End | Holter Pos | 0.4947 | 0.4998 | 0.5036 | 0.5094 | 0.4954 | 0.4963 | 0.4913 | 0.4992 | 0.4899 | 0.5019 | 0.5115 |
| Holter Pos | NoImplant-Ineligible | 0.2460 | 0.2595 | 0.2782 | 0.2588 | 0.2437 | 0.2657 | 0.2510 | 0.2523 | 0.2746 | 0.2600 | 0.2453 |
| Holter Pos | NoImplant-InsDecline | 0.2608 | 0.2521 | 0.2484 | 0.2623 | 0.2618 | 0.2456 | 0.2534 | 0.2441 | 0.2503 | 0.2560 | 0.2516 |
| Holter Pos | NoImplant-PatDecline | 0.2484 | 0.2601 | 0.2436 | 0.2438 | 0.2641 | 0.2574 | 0.2439 | 0.2465 | 0.2414 | 0.2266 | 0.2704 |
| Holter Pos | Pacemaker Implant | 0.2448 | 0.2283 | 0.2299 | 0.2351 | 0.2303 | 0.2313 | 0.2516 | 0.2570 | 0.2337 | 0.2573 | 0.2327 |
| Holter Start | Holter End | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| Stroke | Echo | 0.4995 | 0.5010 | 0.4853 | 0.4979 | 0.4760 | 0.4832 | 0.4587 | 0.4802 | 0.4954 | 0.5046 | 0.4766 |
| Stroke | Holter Start | 0.5005 | 0.4990 | 0.5147 | 0.5021 | 0.5240 | 0.5168 | 0.5413 | 0.5198 | 0.5046 | 0.4954 | 0.5234 |
| Syncope | Echo | 0.5214 | 0.4959 | 0.5094 | 0.4943 | 0.4691 | 0.5142 | 0.4830 | 0.4859 | 0.5078 | 0.4794 | 0.4843 |
| Syncope | Holter Start | 0.4786 | 0.5041 | 0.4906 | 0.5057 | 0.5309 | 0.4858 | 0.5170 | 0.5141 | 0.4922 | 0.5206 | 0.5157 |
| TIA | Echo | 0.4822 | 0.4756 | 0.4896 | 0.5172 | 0.4941 | 0.4611 | 0.5024 | 0.4958 | 0.4944 | 0.4397 | 0.4815 |
| TIA | Holter Start | 0.5178 | 0.5244 | 0.5104 | 0.4828 | 0.5059 | 0.5389 | 0.4976 | 0.5042 | 0.5056 | 0.5603 | 0.5185 |

That matrix can be read in a Bayesian spirit:

**given the month and the current event, what is the probability of the next event?**

In other words, each cell is answering a question like:

- given `2025-01` and `holter positive`, what is the probability of `pacemaker`?
- given `2025-02` and `admit cardiology`, what is the probability of `echo ordered`?
- given `2025-03` and `stress test abnormal`, what is the probability of `cath lab consult`?

This is not Bayesian in the sense of a full belief network with many variables. It is Bayesian in the more direct conditional-probability sense: **given this slice of time and this current event, what next event is likely?**

That perspective is useful because it turns the matrix into more than just a display of Markov model outputs. It becomes a compact comparative view of how process behavior changes across time. If the probability of a transition rises, falls, appears, or disappears from month to month, the matrix makes that visible immediately.

For example, if one month shows a much higher probability for a transition such as `holter positive -> pacemaker`, that may reflect a change in clinical practice, staffing, patient mix, coding behavior, or operational bottlenecks. If another transition weakens over time, that can be equally meaningful. The point is that the same process is being viewed repeatedly through comparable monthly slices, and the matrix makes those conditional differences easy to scan.

So the final pivot is not just a formatting step. It is a way of asking, for each month:

**given this event, what next event became more or less likely?**
