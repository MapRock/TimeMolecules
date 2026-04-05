

## Using `CreateUpdateMarkovProcess` to create and store a Markov model

In Time Molecules, `CreateUpdateMarkovProcess` is the stored procedure used when you want a Markov model to become a first-class stored object in the database rather than just a one-off calculation. Its job is not merely to calculate transition probabilities. It also persists the model definition in `Models`, stores the transition rows in `ModelEvents`, updates `DistinctCases`, and optionally stores deeper path detail in `ModelSequences`.

Conceptually, the procedure does four things. First, it resolves or creates the model definition through `InsertModel`. Second, it clears prior stored transition rows for that model. Third, it invokes `MarkovProcess2` to compute fresh transition metrics. Finally, it writes those results back into the model tables. That makes it the procedure to use when you want a durable model that can later be searched, compared, embedded, or reused.

### Parameters

The main parameters are these:

* `@ModelID INT OUTPUT`
  If `NULL`, the procedure creates or resolves a model and returns its `ModelID`. If you pass an existing `ModelID`, it refreshes that stored model.

* `@EventSet NVARCHAR(MAX)`
  The event set to model, either as a CSV list or a code resolving to a set of events.

* `@enumerate_multiple_events INT = 0`
  Controls how repeated events in a case are handled. `0` collapses duplicates, `1` keeps occurrences separate, and values `>= 2` can append occurrence numbers such as `served1`, `served2`, and so on.

* `@StartDateTime DATETIME` and `@EndDateTime DATETIME`
  Define the modeling window. The metadata says these default conceptually to `1900-01-01` and `2050-12-31`.

* `@transforms NVARCHAR(MAX) = NULL`
  Optional normalization rules for event names. These are hashed and stored through the transforms mechanism.

* `@ByCase BIT = 1`
  When `1`, the model is grouped by `CaseID`. When `0`, events can be treated as one continuous stream.

* `@metric NVARCHAR(20) = NULL`
  The metric used for transition statistics. If omitted, `InsertModel` defaults this to **`Time Between`**.

* `@CaseFilterProperties NVARCHAR(MAX) = NULL`
  JSON key/value filters at the case level. These are also persisted into `ModelProperties`.

* `@EventFilterProperties NVARCHAR(MAX) = NULL`
  JSON key/value filters at the event level, likewise persisted into `ModelProperties`.

* `@InsertSequences BIT = NULL`
  When true, the procedure also stores path/sequence detail in `ModelSequences`. The metadata says this defaults to `1`.

### What gets stored

A successful call stores or refreshes three layers of information:

* the **model definition** in `Models`
* the **first-order transition rows** in `ModelEvents`
* the optional **sequence detail** in `ModelSequences`

That separation is important. `Models` holds the identity and metadata of the model, while `ModelEvents` holds the actual Markov segments such as `EventA -> EventB` with probability and summary statistics. `ModelSequences` is optional and is for richer path analysis.

### Is it idempotent?

The best answer is: **mostly yes at the model-definition level, but not purely as a no-op refresh**. `InsertModel` explicitly checks whether a model with the same effective parameters already exists by calling `ModelsByParameters`. If such a model already exists, it reuses that `ModelID` instead of creating a duplicate. That means repeated calls with the same parameter set are intended to resolve to the same stored model identity rather than create endless duplicates. 

However, this is not “idempotent” in the strict sense of “nothing is redone.” The description of `CreateUpdateMarkovProcess` says it **clears `ModelEvents` and repopulates them** using `MarkovProcess2`, and then updates model statistics such as `DistinctCases`. So the call is idempotent with respect to **which model definition you get**, but it still behaves like a **refresh** operation on the stored contents.

There is one subtle point worth noting. `InsertModel` computes a `ParamHash`, but the hash deliberately does **not** include the event set itself; the comment says this is so events from different models can still be matched for hidden Markov model work. So uniqueness is not based on `ParamHash` alone. The stronger deduplication check comes from `ModelsByParameters`.

### A practical way to think about it

Use `CreateUpdateMarkovProcess` when you have decided that a particular filtered event universe is worth preserving as a reusable model. You give it an event set, a time window, optional transforms, grouping behavior, metric, and filters. It returns a `ModelID`, stores the model definition, stores the transition matrix in row form, and optionally stores the sequence expansions. If you run it again with the same effective definition, you should expect it to resolve to the same model identity and refresh the stored rows rather than invent a brand new model.

### Minimal example

```sql
DECLARE @ModelID INT = NULL;

EXEC dbo.CreateUpdateMarkovProcess
    @ModelID = @ModelID OUTPUT,
    @EventSet = N'arrive,greeted,seated,ordered,served,paid',
    @enumerate_multiple_events = 0,
    @StartDateTime = '1900-01-01',
    @EndDateTime = '2050-12-31',
    @transforms = NULL,
    @ByCase = 1,
    @metric = N'Time Between',
    @CaseFilterProperties = NULL,
    @EventFilterProperties = NULL,
    @InsertSequences = 1;

SELECT @ModelID AS ModelID;
```

That is the basic pattern: call the procedure, capture the returned `ModelID`, and then use that ID to inspect `Models`, `ModelEvents`, or downstream comparison routines.

---

One caution: I based this on the current TimeSolution scripts and metadata comments, and the procedure name there is **`CreateUpdateMarkovProcess`**, not `CreateUpdateMarkovModel`. If you want, I can turn this into a polished markdown article in your usual style.
