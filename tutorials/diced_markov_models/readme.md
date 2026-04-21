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

The last part of the script turns the monthly diced models into a matrix where each row is an `EventA -> EventB` transition and each column is a month. The cell value is the transition probability for that month.

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
