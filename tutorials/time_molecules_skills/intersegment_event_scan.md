# Skill: Investigate Lateral Intersegment Events Around a Slow Markov Segment

## Purpose

Use this skill when a Markov model segment looks unusually slow and you want to inspect not only the cases that make up the segment, but also any other events that occurred during the same time window. This helps determine whether the delay may have been influenced by external or unrelated events outside the model itself.

This skill is discussed in <i>[Time Molecules](https://technicspub.com/time-molecules/)</i> on page 182, Lateral Intersegment Event Scan, and involves **Code 44** and **Code 45**.

## What this skill does

This pattern uses two steps:

1. **Drill through to the specific Markov segment** to find the cases and time gaps that make up the segment.
2. **Scan for intersegment events** that occurred during the same time gap, even if those events are not part of the Markov model or its event set.

This is useful when a segment delay may have been caused by something outside the modeled process, such as traffic, outages, or unrelated operational events.

## Code 44: Drill through to the segment

Use `ModelDrillThrough` to return the rows that make up the segment you want to investigate.

```sql
SELECT * 
FROM dbo.[ModelDrillThrough](24,'lv-csv1','homedepot1')
````

Primary reference: [TimeMolecules_Code44.sql](https://github.com/MapRock/TimeMolecules/blob/main/book_code/sql/TimeMolecules_Code44.sql)

### What to look for

Review the returned rows and identify:

* the cases that make up the segment
* the elapsed time for each case
* any row whose elapsed time is noticeably larger than the others

The point of this step is to isolate the offending case or cases for the segment.

## Code 45: Retrieve lateral intersegment events

Once you know the segment is anomalous, use `IntersegmentEvents` to retrieve all events that occurred during the time gap of the segment.

```sql
SELECT CaseID, EventID, Event, EventDate
FROM dbo.[IntersegmentEvents](24,'lv-csv1','homedepot1')
```

Primary reference: [TimeMolecules_Code45.sql](https://github.com/MapRock/TimeMolecules/blob/main/book_code/sql/TimeMolecules_Code45.sql)

### What this returns

This returns events that occurred between the start and end timestamps of the segment instances for that Markov segment, including events that are:

* not part of the model
* not part of the model’s event set
* potentially unrelated in a strict process sense, but still relevant contextually

This is the lateral scan.

## Why this matters

A Markov model can show that a segment took too long, but it does not necessarily explain why. The delay may not be caused by a failure inside the modeled process. It may be influenced by outside conditions that happened during the same time interval.

For example:

* traffic events
* system outages
* environmental conditions
* scheduled maintenance
* unrelated but interfering business activity

Without this step, it is easy to over-interpret a slow segment as an internal process issue when the real cause may be external.

## Typical workflow

### Step 1

Run `ModelDrillThrough(ModelID, EventA, EventB)` to inspect the rows behind the segment.

### Step 2

Identify whether one or more cases have unusually long elapsed times.

### Step 3

Run `IntersegmentEvents(ModelID, EventA, EventB)` to retrieve all events logged during those segment time windows.

### Step 4

Review returned events for plausible explanatory clues.

## Example interpretation

Suppose `ModelDrillThrough(24,'lv-csv1','homedepot1')` shows that one row took much longer than the others.

Then `IntersegmentEvents(24,'lv-csv1','homedepot1')` may reveal an event such as `heavytraffic` during that same time interval.

That `heavytraffic` event is not part of the pickup-route model, but it may help explain the longer transition time. It is therefore a lateral intersegment event: outside the modeled segment, but inside the relevant time window.

## Inputs

* `ModelID`
* `EventA`
* `EventB`

## Outputs

### `ModelDrillThrough`

Returns the rows that make up the specified segment.

### `IntersegmentEvents`

Returns all events occurring during the segment time gap, including events outside the model.

## When to use this skill

Use this skill when:

* a segment duration looks anomalous
* you want contextual evidence around a slow transition
* the model alone does not explain the delay
* you suspect outside influences affected the process

Compelling examples include:

- **Supply chain / logistics:** a delivery-leg transition suddenly takes much longer than normal, and you want to see whether weather alerts, traffic events, warehouse slowdowns, fuel-system issues, or port delays occurred during that time.
- **Healthcare:** the time between triage and imaging, lab, discharge, or admission becomes anomalous, and you want to see whether staffing shortages, equipment downtime, surges in patient volume, or unrelated emergency events were happening at the same time.
- **Customer service / call center:** a support case stalls between assignment and resolution, and you want to see whether telephony outages, CRM failures, escalations, agent absences, or unusual spikes in inbound volume occurred during that interval.
- **Manufacturing / IoT:** a machine process step runs long, and you want to check whether nearby alarms, maintenance events, sensor anomalies, material shortages, or network interruptions happened during the gap.
- **Retail / point of sale:** checkout, replenishment, or fulfillment transitions slow down, and you want to see whether staffing changes, payment gateway issues, inventory sync delays, weather events, or unusual store traffic occurred at the same time.
- **IT / platform operations:** a deployment, batch run, or system workflow takes longer than expected, and you want to see whether infrastructure alerts, job contention, upstream failures, security scans, or scheduled maintenance overlapped the interval.
- **Banking / claims / case management:** a case moves slowly between stages, and you want to check whether compliance reviews, document-ingestion failures, holidays, downstream system outages, or workload spikes were present during the same period.
- **AI agents / orchestration:** an agent step suddenly takes much longer than usual, and you want to know whether tool failures, rate limits, model latency, approval bottlenecks, human interventions, or competing workflows occurred during that time.
- **Cross-domain enterprise analysis:** any time one process looks abnormal and you suspect the cause may have come from a completely different domain, source system, or event stream than the one used to build the Markov model.

This skill is especially useful in environments where event streams are broad and diverse. In those settings, the cause of an anomaly may lie outside the local process, outside the event set, or even outside the business domain that originally produced the model.

## Key idea

`ModelDrillThrough` tells you **which segment instances were slow**.

`IntersegmentEvents` helps you investigate **what else was happening during that same time**.

Together, they connect the modeled process to the broader event reality surrounding it.

## Source references

* [Model event drillthrough skill example](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/model_event_drillthrough.md)
* [Code 44 – TimeMolecules_Code44.sql](https://github.com/MapRock/TimeMolecules/blob/main/book_code/sql/TimeMolecules_Code44.sql)
* [Code 45 – TimeMolecules_Code45.sql](https://github.com/MapRock/TimeMolecules/blob/main/book_code/sql/TimeMolecules_Code45.sql)

