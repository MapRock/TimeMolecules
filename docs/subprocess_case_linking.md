
# Linking Subprocesses with Case Properties

One of the practical problems in process analysis is how to connect subprocesses without having to reconstruct a giant bag of events and then infer structure afterward. A simpler approach is to let each subprocess be its own case, and then attach a small amount of calling context to that case through case-level properties.

This keeps the model event-centric and lightweight.

## Restaurant Example

Suppose the main dining-room case has these case properties:

```json
{"EmployeeID":1,"LocationID":1}
```

In this example, `EmployeeID` is the waitstaff for the table, and `LocationID` is the restaurant location.

The dining-room case might contain events like `GuestSeated`, `DrinksServed`, `OrderSubmitted`, `FoodDelivered`, and `BillPaid`.

When `OrderSubmitted` happens, that event starts a kitchen subprocess. The kitchen work is important enough to be its own case, because it has its own sequence of events, timings, bottlenecks, and possibly its own staff.

For example, the kitchen case might contain `OrderReceived`, `PrepStarted`, `CookingStarted`, `PlatingCompleted`, and `OrderReady`.

That kitchen work has a different `CaseID`, but it is linked back to the dining-room case.

## Kitchen Case Properties

Using camel case names, the kitchen case properties should include the calling context:

```json
{
  "LocationID": 1,
  "CallingCaseID": 1001,
  "CallingEvent": "OrderSubmitted",
  "CallingEventDateTime": "2026-03-21T18:42:13"
}
```

Where:

* `LocationID` keeps the subprocess tied to the same restaurant
* `CallingCaseID` points back to the main dining-room case
* `CallingEvent` records which event started the subprocess
* `CallingEventDateTime` records when that triggering event happened

If the kitchen worker is known and useful at the case level, you could also include:

```json
{
  "LocationID": 1,
  "KitchenEmployeeID": 12,
  "CallingCaseID": 1001,
  "CallingEvent": "OrderSubmitted",
  "CallingEventDateTime": "2026-03-21T18:42:13"
}
```

I would not reuse `EmployeeID` here unless it means the same role as in the parent case. In the dining-room case, `EmployeeID` means the waitstaff. In the kitchen case, that would likely be a different role. A more specific name such as `KitchenEmployeeID` is cleaner.

## Why This Helps

This approach reduces the need to force everything into one flat process instance.

Instead of treating the entire restaurant operation as one large bag of events, it allows each meaningful unit of work to be modeled as its own case:

* the dining-room experience is one case
* the kitchen preparation is another case
* a payment authorization could be another case
* a delivery dispatch could be another case

Each case can be analyzed on its own, while still preserving lineage through the calling properties.

## Function-Like Behavior

This makes a subprocess behave a little like a function call:

* the parent case emits a triggering event
* that event instantiates another case
* the child case performs its own work
* the child case eventually emits a completion event
* the parent case continues when it receives the result

In the restaurant example:

* `OrderSubmitted` is the call
* the kitchen case is the function execution
* `OrderReady` is the return signal
* the waitstaff then picks it up and resumes the dining-room process

## Why This Is Better Than Rebuilding Structure Later

A lot of process-mining style work starts with a pile of events and then tries to infer what the subprocesses were.

This approach moves some of that structure into the data model itself.

That has several advantages:

* subprocesses are explicit
* cross-case lineage is preserved
* timing between parent and child processes is easy to analyze
* process chains become easier to stitch together
* AI agents can traverse linked cases more naturally

Instead of trying to rediscover the relationship after the fact, the relationship is already present.

## Recommended Convention

For linked subprocesses, standardize on these camel case case properties:

* `CallingCaseID`
* `CallingEvent`
* `CallingEventDateTime`

Then keep any subprocess-specific properties separate, such as:

* `KitchenEmployeeID`
* `LocationID`
* `StationID`
* `PriorityCode`

## Summary

In the restaurant example, the kitchen case should have its own `CaseID`, but its case properties should include the calling context from the dining-room case.

A good kitchen case property set would be:

```json
{
  "LocationID": 1,
  "KitchenEmployeeID": 12,
  "CallingCaseID": 1001,
  "CallingEvent": "OrderSubmitted",
  "CallingEventDateTime": "2026-03-21T18:42:13"
}
```

This gives a simple and scalable way to link subprocesses without having to reconstruct everything from a flat event log. It also nudges the model toward a more agent-like and function-like structure, where cases can call other cases and return results.

