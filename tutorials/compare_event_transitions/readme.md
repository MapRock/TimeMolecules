

# Comparing competing transitions from the same event

One of the most compelling things you can do with a Markov model is not just see that a process branches, but ask **what is different about the cases that went one way versus another**.

Suppose one event leads to multiple next events:

* `leavehome -> arrivework`
* `leavehome -> heavytraffic`

The branching itself is already useful, because it shows that after `leavehome`, the process does not always unfold the same way. But the deeper value comes when you drill through to the underlying events behind each transition and compare their event-level properties.

That comparison is often where the real insight is.

If the `arrivework` branch tends to have one set of numeric and categorical properties, while the `heavytraffic` branch tends to have another, then the branch is not just a structural fork in the model. It is a measurable difference between two populations of events.

In other words:

* the Markov model shows **where** the process diverges
* the drillthrough shows **which cases** followed each path
* the event property comparison shows **what is different** about those paths

That is a very practical pattern for analysis. It lets you move from “these are two possible next events” to “these are the conditions, measurements, or categories that tend to distinguish one next event from the other.”

## What this tutorial script does

This script compares the **destination events** of two competing transitions from the same source event.

In the example:

* source event: `leavehome`
* transition A destination: `arrivework`
* transition B destination: `heavytraffic`

The script:

1. selects a model
2. runs `sp_ModelDrillThrough` for both transitions
3. stores the drillthrough rows in `WORK.ModelDrillThrough` under separate session IDs
4. uses only `EventB_ID` from each drillthrough set, because that is the divergent event being compared
5. joins those destination events to `dbo.EventPropertiesParsed`
6. aggregates numeric properties with count, average, standard deviation, min, and max
7. aggregates alpha properties by value counts
8. presents two final comparison displays
9. cleans up the session rows from `WORK.ModelDrillThrough`

This is important: the comparison is intentionally based on **EventB only**, not both ends of the transition, because the point is to compare the properties of the two different next events reached from the same source event. 

## Why this is analytically valuable

A branch in a model is often the point where you most want explanation.

If a source event leads to two different outcomes, the natural business question is:

**What tends to distinguish the cases that went this way from the cases that went that way?**

This script helps answer that by comparing the event-level property values attached to the destination events of the two transitions.

That can reveal differences such as:

* higher or lower numeric values on one branch
* different distributions of categorical values
* different source columns or property sources dominating one branch
* different operational contexts associated with one outcome versus the other

So instead of treating the Markov model as just a structural graph, this pattern turns it into a way to compare competing process outcomes in detail.

## Tutorial script

See: https://github.com/MapRock/TimeMolecules/blob/main/tutorials/compare_event_transitions/compare_event_transitions.sql

## How to read the output

The first final display compares numeric properties for the two destination-event populations.

| PropertyName | PropertySource | SourceColumnID | TransA_Count | TransA_Avg | TransA_StDev | TransA_Min | TransA_Max | TransB_Count | TransB_Avg | TransB_StDev | TransB_Min | TransB_Max | AvgDiff_TransA_minus_TransB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Fuel | 0 | 23 | 5 | 33 | 14.7648230602334 | 15 | 50 | 8 | 47 | 7.98212288268514 | 31 | 55 | -14 |

Useful things to look for:

* properties with very different averages
* properties with very different min/max ranges
* properties with higher spread on one branch than the other
* properties present on one branch but missing on the other

The second final display compares alpha properties by value count.

Useful things to look for:

* values that appear mostly in one branch
* values that are balanced versus highly skewed
* categories that may help explain why one outcome happened rather than the other

## Why the script uses `EventB_ID`

The source event is the same in both transitions. The difference is in the destination event.

So the script focuses on `EventB_ID` because that is the event that represents the divergent outcome. Comparing `EventA_ID` as well would dilute the comparison by mixing in the common starting point. The question here is not “what does the shared source event look like,” but rather “what is different about the events that cases reached after the branch?” 

## Practical uses

This pattern is useful anywhere a process can branch into multiple next events and you want to understand the difference between those branches.

Examples include:

* different customer outcomes after the same starting action
* different patient flow outcomes after the same intake event
* different operational routes after the same initial step
* different AI agent next-step behaviors after the same context or prompt state

## One likely next improvement

A good next enhancement would be to add percentages for alpha values, not just counts, because the two transitions may have different row totals. That makes the comparison easier when one branch is much more common than the other.

