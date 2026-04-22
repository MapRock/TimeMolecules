# Event Properties in Time Molecules

Event properties give an event more meaning than just its name and timestamp. They let the event carry facts, goals, forecasts, context, and even the logic that caused it to happen. In Time Molecules, this makes an event more than a logged action. It becomes a compact package of state, intention, prediction, and causation.

These values are typically stored as JSON key-value pairs, where the key is the `PropertyName`.

## Why event properties matter

A plain event such as `TruckArrived`, `StoreVisit`, `ClaimApproved`, or `PatientDischarged` tells us that something happened. Event properties help answer the deeper questions:

* What was true when it happened?
* What was supposed to happen?
* What was predicted to happen?
* What had been accumulating up to that point?
* What logic or function caused the event to fire?

That is useful for reporting, process analysis, auditing, optimization, and reasoning over why outcomes occurred.

---

## The four property sets

Time Molecules uses four separate property sets for events. These are stored as separate JSON values in the `EventProperties` table.

### 1. ActualProperties

`ActualProperties` describe what was true at the time the event occurred.

This is the factual state of the world when the event fired. These are not goals or predictions. They are measurements, observations, or recorded values tied to the event.

Examples:

* the actual fuel level of a truck at arrival
* the actual amount spent during a shopping event
* the actual temperature of a machine
* the actual number of items in an order
* the actual wait time of a patient

Example JSON:

```json
{
  "FuelLevelGallons": 12.4,
  "CargoWeightLbs": 8400,
  "MilesDriven": 118
}
```

In a personal example:

```json
{
  "AmountSpent": 100,
  "StoreName": "Albertsons"
}
```

These values are the factual baseline for the event.

---

### 2. IntendedProperties

`IntendedProperties` describe the target or desired outcome.

This is what a person, team, organization, or system is trying to achieve. These values are about purpose and goals. They are not forecasts. They represent what is being aimed at.

Examples:

* target revenue for the year
* intended destination of a truck
* desired service level
* target inventory level
* intended appointment duration

Example JSON:

```json
{
  "Destination": "Boise Distribution Center",
  "TargetArrivalTime": "2026-04-22T10:00:00",
  "TargetFuelReserveGallons": 8
}
```

A simple business example:

```json
{
  "AnnualIncome": 100000
}
```

That value says what is being targeted, whether or not it is realistic.

---

### 3. ExpectedProperties

`ExpectedProperties` describe the forecast or prediction.

These values represent what is currently believed will happen. They may come from machine learning models, heuristics, business rules, simulations, or human estimates. They are not necessarily what we want. They are what we expect.

Examples:

* forecasted revenue for the year
* expected arrival time based on traffic
* predicted fuel remaining at destination
* expected churn risk
* expected delay in a medical workflow

Example JSON:

```json
{
  "ExpectedArrivalTime": "2026-04-22T10:35:00",
  "ExpectedFuelAtDestinationGallons": 3.2
}
```

Income example:

```json
{
  "AnnualIncome": 80000
}
```

This is where the distinction becomes important:

* **Intended** = what we are trying to achieve
* **Expected** = what we currently believe will happen
* **Actual** = what really happened

That difference is analytically powerful.

---

### 4. AggregationProperties

`AggregationProperties` describe rolled-up context across multiple events.

These values usually come from summarization logic such as windowing functions, stream processing, rolling totals, averages, counts, or other aggregations. They provide broader context for interpreting a single event.

Examples:

* fuel consumed so far on a route
* average response time over the last 20 events
* cumulative sales for the day
* number of failed logins in the last hour
* running total of claims processed

Example JSON:

```json
{
  "FuelConsumedRouteToDate": 44.7,
  "StopsCompleted": 6,
  "AverageMinutesPerStop": 18.3
}
```

These values help place an event inside a broader pattern.

---

## The hardest distinction: intended vs expected

This is often the most subtle and important distinction.

Suppose someone intends to make `$100,000` this year, but the current forecast says they will make only `$80,000`.

Then:

```json
IntendedProperties:
{
  "AnnualIncome": 100000
}
```

```json
ExpectedProperties:
{
  "AnnualIncome": 80000
}
```

Those are not duplicates. They answer different questions.

* `IntendedProperties` answer: **What are we trying to achieve?**
* `ExpectedProperties` answer: **What do we currently think will happen?**

This gives three useful comparisons:

### Actual vs Intended

Did we achieve the goal?

### Expected vs Intended

Do we appear to be on track, or are we projected to miss the goal?

### Actual vs Expected

Was the forecast accurate?

This allows event streams to support performance management, intervention, and model evaluation.

---

## TriggerFunction: why the event happened

In addition to the property sets, the `EventProperties` table can also store a `TriggerFunction`.

This is optional, but it is important.

`TriggerFunction` is not about what was true during the event. It is about what caused the event to fire. It records the decision logic, function, rule, Prolog clause, REST call, or other mechanism that triggered the event.

This is different from `ActualProperties`.

* `ActualProperties` describe the event
* `TriggerFunction` describes the immediate cause of the event

For example:

* Hunger may be the reason that triggered a `GoToStore` event
* Spending `$100` is part of what actually happened during that event

That is the difference between **cause** and **state**.

---

## Why TriggerFunction is useful

Capturing the trigger helps support:

* reasoning analysis
* auditability
* debugging of automated decisions
* improvement of trigger logic
* comparison of competing rule sets or models

It lets you ask questions such as:

* Which trigger functions most often produce undesirable outcomes?
* Which business rule is associated with the best downstream process results?
* Which Prolog clause tends to lead to rework, delay, or overspending?
* Which external decision API produces the most reliable event triggers?

Without the trigger, you may know what happened. With the trigger, you can start to reason about why it happened.

---

## Suggested TriggerFunction format

A good format is JSON containing the function name and an array of input parameters.

Example:

```json
{
  "FunctionName": "GoToStoreDecision",
  "InputParameters": [
    { "PropertyName": "HungerLevel", "PropertyValue": 9 },
    { "PropertyName": "CashOnHand", "PropertyValue": 120 },
    { "PropertyName": "DistanceToStoreMiles", "PropertyValue": 1.2 }
  ]
}
```

Example using an external call:

```json
{
  "FunctionName": "POST /inventory/reorder-check",
  "InputParameters": [
    { "PropertyName": "ItemID", "PropertyValue": 4412 },
    { "PropertyName": "QuantityOnHand", "PropertyValue": 3 },
    { "PropertyName": "ReorderThreshold", "PropertyValue": 10 }
  ]
}
```

Example using Prolog or rules logic:

```json
{
  "FunctionName": "restock_item_if_below_threshold",
  "InputParameters": [
    { "PropertyName": "ItemID", "PropertyValue": 4412 },
    { "PropertyName": "StockLevel", "PropertyValue": 3 },
    { "PropertyName": "Threshold", "PropertyValue": 10 }
  ]
}
```

The exact format can evolve, but the main point is to preserve both the triggering logic and the inputs that drove it.

---

## How these pieces work together

Taken together, these fields let a single event express:

* **ActualProperties**: what was true
* **IntendedProperties**: what was desired
* **ExpectedProperties**: what was forecast
* **AggregationProperties**: what had been accumulating or trending
* **TriggerFunction**: what caused the event to happen

That is a very rich structure.

It means an event can serve not only as a transaction record, but also as a compact unit of reasoning. It can support operational analysis, process intelligence, model evaluation, and eventually causal or rule-based analysis.

---

## Example: delivery event

Imagine a `TruckArrived` event.

### ActualProperties

```json
{
  "ArrivalTime": "2026-04-22T10:42:00",
  "FuelLevelGallons": 3.1,
  "CargoWeightLbs": 7800
}
```

### IntendedProperties

```json
{
  "TargetArrivalTime": "2026-04-22T10:00:00",
  "TargetFuelReserveGallons": 8,
  "Destination": "Boise Distribution Center"
}
```

### ExpectedProperties

```json
{
  "ExpectedArrivalTime": "2026-04-22T10:35:00",
  "ExpectedFuelLevelGallons": 3.4
}
```

### AggregationProperties

```json
{
  "FuelConsumedRouteToDate": 44.7,
  "StopsCompleted": 6,
  "AverageMinutesPerStop": 18.3
}
```

### TriggerFunction

```json
{
  "FunctionName": "dispatch_next_stop",
  "InputParameters": [
    { "PropertyName": "CurrentStop", "PropertyValue": 6 },
    { "PropertyName": "RemainingStops", "PropertyValue": 2 },
    { "PropertyName": "TrafficDelayMinutes", "PropertyValue": 17 }
  ]
}
```

This one event now tells a much richer story:

* what happened
* what should have happened
* what was expected to happen
* how the route had been going
* what logic sent the truck there

---

## Final thought

The design of event properties in Time Molecules makes events much more than timestamps attached to labels. It lets them hold factual measurements, goals, forecasts, rollups, and causal logic in one place.

That gives analysts and AI systems something far more useful than a bare event log. It gives them a structure that can support comparison, traceability, diagnosis, and improvement.

In that sense, event properties help turn event streams into something closer to process memory.
