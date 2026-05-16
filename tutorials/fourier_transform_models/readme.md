
# Frequency Domain Analysis and FFT Models in Time Molecules

## Purpose

This tutorial explains how Fast Fourier Transform / frequency domain analysis can fit into Time Molecules.

Time Molecules is usually introduced through event sequences and Markov models. That is the natural path because Markov models describe how one event tends to follow another. However, some event streams are also traditional time series. In those cases, the Event Ensemble can supply the ordered values needed for conventional time-based analysis, including FFT.

The basic idea is:

> The Event Ensemble can retrieve the signal.  
> FFT decomposes the signal into component cycles.  
> Those components can later be stored as a model, with `Models.ModelType = 'FFT'`.

This is not fully implemented yet. The data structure exists to retrieve the relevant events and metrics, but the storage of FFT model components still needs to be added in a future refresh.

This tutorial is conceptual and architectural.

---

## Background: frequency domain analysis

In *[Enterprise Intelligence](https://technicspub.com/enterprise-intelligence/)* (page 353), frequency domain analysis is discussed in the context of the Insight Space Graph rather than Time Molecules. The key idea is that a time series can be decomposed into spectral components. Each component can be represented by values such as frequency, amplitude, and phase. Similar components across different time series may suggest a common factor, driver, or periodic process worth investigating. :contentReference[oaicite:0]{index=0}

A useful analogy is a prism. A prism decomposes light into component colors. Fourier analysis decomposes a signal into component frequencies. In the same way that a sound engineer can modify a recording by changing frequency components, an analytical system can study a signal by identifying the cycles that compose it. :contentReference[oaicite:1]{index=1}

In Time Molecules, this becomes another way to reason over event data.

---

## Why FFT belongs in Time Molecules

Time Molecules is not only about discrete business process events such as:

```text
arrive -> greeted -> seated -> ordered -> served -> paid
````

It can also hold repeated measurements from machines, systems, sensors, financial feeds, or other observational streams.

For example, an IoT device might emit regular readings:

```text
temperature_reading
temperature_reading
temperature_reading
temperature_reading
...
```

Each event may carry metrics such as:

| Metric      | Example |
| ----------- | ------: |
| Temperature |    72.5 |
| Humidity    |    41.2 |
| Pressure    |    29.9 |
| Vibration   |   0.018 |

If these readings occur at regular intervals, or can be normalized into regular intervals, they form a signal.

That signal can be passed into an FFT process to decompose it into component cycles.

---

## Markov models versus FFT models

A Markov model asks:

> Given that event A occurred, what tends to happen next?

An FFT model asks:

> What repeating cycles appear inside this numeric signal over time?

These are different kinds of models, but both are models derived from the Event Ensemble.

| Model type    | Main question                                             | Typical source                              |
| ------------- | --------------------------------------------------------- | ------------------------------------------- |
| `MarkovChain` | What event tends to follow another event?                 | Ordered event sequences                     |
| `Bayesian`    | How does one condition change the probability of another? | Event/case properties and observed outcomes |
| `FFT`         | What cycles or frequencies compose this signal?           | Regular numeric readings over time          |

This means FFT should not be treated as outside Time Molecules. It is part of the broader idea that event data can be transformed into reusable analytical structures.

---

## Important distinction: sequence, not case process

When using Time Molecules for FFT-style analysis, the data should usually be treated as a single ordered sequence.

For a Markov-style process, `@ByCase = 1` is often the default, because transitions are calculated within each case.

For FFT-style signal extraction, the event stream should be analyzed as one signal:

```sql
@ByCase = 0
```

That means the selected readings are treated as one ordered sequence over time.

The event set should usually contain only one event type:

```sql
@EventSet = N'temperature_reading'
```

This is different from a process model where the event set might contain several process steps.

---

## Example source scenario

Suppose an IoT device emits temperature readings every minute.

Each event might look conceptually like this:

| EventDate           | Event                 | Metric      | Value |
| ------------------- | --------------------- | ----------- | ----: |
| 2026-05-01 00:00:00 | `temperature_reading` | Temperature |  72.1 |
| 2026-05-01 00:01:00 | `temperature_reading` | Temperature |  72.2 |
| 2026-05-01 00:02:00 | `temperature_reading` | Temperature |  72.4 |
| 2026-05-01 00:03:00 | `temperature_reading` | Temperature |  72.3 |

The selected metric is:

```text
Temperature
```

The selected event is:

```text
temperature_reading
```

The selected period might be:

```text
2026-05-01 through 2026-05-31
```

The result is a time series:

```text
72.1, 72.2, 72.4, 72.3, ...
```

FFT can decompose that signal into component frequencies.

---

## Why the metric matters

An IoT event may deliver several values at the same time.

For example:

```json
{
  "temperature": 72.1,
  "humidity": 41.2,
  "pressure": 29.9
}
```

The event type alone is not enough. The system also needs to know which metric is being analyzed.

For the same event stream, there may be different FFT models:

| ModelType | EventSet      | Metric        |
| --------- | ------------- | ------------- |
| `FFT`     | `iot_reading` | `temperature` |
| `FFT`     | `iot_reading` | `humidity`    |
| `FFT`     | `iot_reading` | `pressure`    |

Each metric may have different cycles and different spectral components.

This fits the Time Molecules idea that the Event Ensemble can hold many kinds of event and property values, while models are built from selected views of those events.

---

## Relationship to `MarkovProcess2`

The existing Time Molecules machinery can already retrieve ordered event data for a selected event set, date range, metric, and filtering context.

For FFT-style analysis, the call pattern should conceptually resemble a `MarkovProcess2` selection, but with important constraints:

| Parameter                | FFT-style usage                                                                           |
| ------------------------ | ----------------------------------------------------------------------------------------- |
| `@EventSet`              | Usually one event type, such as `temperature_reading`.                                    |
| `@ByCase`                | Should be `0`, because the data is analyzed as one sequence.                              |
| `@metric`                | The numeric value to analyze, such as temperature, humidity, closing price, or vibration. |
| `@StartDateTime`         | Start of the signal window.                                                               |
| `@EndDateTime`           | End of the signal window.                                                                 |
| `@CaseFilterProperties`  | Optional filter to select a device, location, stock symbol, machine, patient, etc.        |
| `@EventFilterProperties` | Optional filter to select event-level conditions.                                         |
| `@transforms`            | Usually NULL, unless event normalization is needed before signal extraction.              |

A conceptual call might look like:

```sql
DECLARE @SessionID UNIQUEIDENTIFIER = NEWID();

EXEC dbo.MarkovProcess2
    @EventSet = N'temperature_reading',
    @enumerate_multiple_events = 0,
    @StartDateTime = '2026-05-01',
    @EndDateTime = '2026-05-31',
    @transforms = NULL,
    @ByCase = 0,
    @metric = N'Temperature',
    @CaseFilterProperties = N'{"DeviceID":101}',
    @EventFilterProperties = NULL,
    @SessionID = @SessionID;
```

In the current system, this kind of call can support retrieval of the event sequence. The FFT decomposition itself and the persistence of FFT model components are future implementation work.

---

## What an FFT model would store

A future FFT model can use the existing model framework by storing the model header in `Models` with:

```text
Models.ModelType = 'FFT'
```

The model parameters would identify the signal:

| Model parameter         | Example               |
| ----------------------- | --------------------- |
| `ModelType`             | `FFT`                 |
| `EventSet`              | `temperature_reading` |
| `StartDateTime`         | `2026-05-01`          |
| `EndDateTime`           | `2026-05-31`          |
| `Metric`                | `Temperature`         |
| `ByCase`                | `0`                   |
| `CaseFilterProperties`  | `{"DeviceID":101}`    |
| `EventFilterProperties` | NULL                  |

The model items would store the spectral components.

A spectral component can be represented as:

| Component attribute   | Meaning                                                              |
| --------------------- | -------------------------------------------------------------------- |
| Frequency             | How often the cycle repeats per unit of time.                        |
| Amplitude             | Strength or magnitude of the cycle.                                  |
| Phase                 | Offset or timing shift of the cycle relative to the reference point. |
| Rank                  | Importance of the component, usually ranked by amplitude.            |
| Period                | Cycle length, derived from frequency.                                |
| Residual contribution | Optional measure of how much the component helps explain the signal. |

The uploaded Enterprise Intelligence text describes spectral components as tuples with frequency, amplitude, and phase, and explains that the top components are often ranked by amplitude as the “dominant frequencies.” 

---

## Example conceptual FFT model items

Suppose the FFT process finds three dominant components for a temperature signal.

| ModelID | ComponentRank | Frequency |      Period | Amplitude | Phase |
| ------: | ------------: | --------: | ----------: | --------: | ----: |
|    9001 |             1 |   0.04167 |    24 hours |       8.2 | -1.12 |
|    9001 |             2 |   0.00595 |   168 hours |       2.9 |  0.44 |
|    9001 |             3 |   0.00070 | 1,428 hours |       1.1 |  2.03 |

This might indicate:

| Component      | Interpretation                                         |
| -------------- | ------------------------------------------------------ |
| 24-hour cycle  | Daily heating/cooling cycle                            |
| 168-hour cycle | Weekly operational cycle                               |
| Longer cycle   | Possible seasonal, maintenance, or environmental cycle |

The model itself does not need to explain the meaning. It records the components so a human, SME, AI agent, or knowledge graph process can reason over them.

---

## Why component similarity matters

The great value of FFT models is not only explaining one signal. It is finding signals that share components.

For example, suppose two devices have similar spectral components:

| Signal               | Frequency | Amplitude | Phase |
| -------------------- | --------: | --------: | ----: |
| Device A temperature |   0.04167 |       8.2 | -1.12 |
| Device B vibration   |   0.04166 |       8.1 | -1.10 |

The similarity of frequency, amplitude, and phase suggests that both signals may be responding to a common driver.

That common driver might be:

| Possible driver   | Example                             |
| ----------------- | ----------------------------------- |
| Environmental     | Outdoor temperature cycle           |
| Operational       | Shift schedule                      |
| Mechanical        | Shared equipment behavior           |
| Business calendar | Pay cycle, tax cycle, holiday cycle |
| Biological        | Circadian rhythm                    |
| Market            | Shared seasonal demand              |

The Enterprise Intelligence text makes the same point with stock prices: two time series may not be strongly correlated overall, but they may share a frequency component that suggests a common seasonal or structural factor. 

---

## Important warning: similarity is only a clue

A shared frequency does not prove causation.

It does not automatically mean two signals have the same cause. It means they share a periodic component worth investigating.

The right interpretation is:

> Shared spectral components are hints toward common drivers.

They are another way to connect dots, not the final explanation.

This is consistent with the broader Time Molecules / Enterprise Knowledge Graph role. The model records useful analytical structure. Human and AI intelligences reason through the meaning.

---

## Minimum data points and cycle length

FFT analysis depends on having enough data to observe the cycles being studied.

For annual seasonality, the Enterprise Intelligence text says that at least two full years are ideal as a minimum, while three to five years is better for robust analysis because more cycles help distinguish real seasonality from noise or anomalies. It also warns that overly long histories may include patterns that are no longer valid. 

The same principle applies in Time Molecules.

| Desired cycle    | Minimum practical data                    |
| ---------------- | ----------------------------------------- |
| Daily cycle      | At least several days of regular readings |
| Weekly cycle     | At least several weeks                    |
| Monthly cycle    | At least several months                   |
| Annual cycle     | At least two years, preferably more       |
| Multi-year cycle | Multiple full cycles, if practical        |

There is always a trade-off:

| Too little history                    | Too much history                 |
| ------------------------------------- | -------------------------------- |
| Weak or unreliable cycle detection    | Old patterns may no longer apply |
| Hard to distinguish signal from noise | Current behavior may be obscured |
| Anomalies may look like cycles        | More compute and storage cost    |

Time Molecules should treat the selected time window as part of the model definition.

---

## Regular intervals matter

FFT expects a signal sampled at regular intervals.

Many event streams are irregular. For example:

```text
08:01:04
08:03:22
08:07:59
08:08:10
```

That is not a clean one-minute or one-hour signal.

For FFT use, the Event Ensemble may need a preprocessing step to regularize the signal:

| Method        | Description                                            |
| ------------- | ------------------------------------------------------ |
| Resampling    | Convert irregular events into regular intervals.       |
| Aggregation   | Average, sum, min, or max values within each interval. |
| Interpolation | Fill missing readings between observed values.         |
| Filtering     | Remove invalid or outlier readings.                    |
| Windowing     | Analyze a specific time range.                         |

This preprocessing step should be explicit because it affects the meaning of the FFT model.

A future FFT model should store enough parameters to know how the signal was regularized.

---

## Relationship to the Insight Space Graph

In *Enterprise Intelligence*, frequency domain analysis is described in the context of the Insight Space Graph. There, the time series might come from a BI query, such as daily closing stock prices or sales by day. The Fourier model becomes another model attached to a query-defined time series. 

In Time Molecules, the signal comes from the Event Ensemble instead.

| Enterprise Intelligence / ISG             | Time Molecules                             |
| ----------------------------------------- | ------------------------------------------ |
| QueryDef defines a time series            | EventSet + filters define a signal         |
| Measure node supplies the value           | Metric supplies the value                  |
| Fourier model attached to query           | FFT model attached to event-derived signal |
| Model items store spectral components     | Model items store spectral components      |
| Similar components suggest common factors | Similar components suggest common drivers  |

So the concept transfers cleanly. The difference is the source of the signal.

---

## Possible future table structure

The current model structure can identify an FFT model at the header level using `Models.ModelType = 'FFT'`.

A future implementation may need a table for FFT components, for example:

```sql
CREATE TABLE dbo.ModelFFTComponents
(
    ModelFFTComponentID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ModelID INT NOT NULL,
    ComponentRank INT NOT NULL,
    Frequency FLOAT NOT NULL,
    Period FLOAT NULL,
    PeriodUnit NVARCHAR(50) NULL,
    Amplitude FLOAT NOT NULL,
    Phase FLOAT NOT NULL,
    PowerValue FLOAT NULL,
    VarianceExplained FLOAT NULL,
    IsDominant BIT NOT NULL DEFAULT 0,
    CreatedDateTime DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

This is only an illustrative structure. The actual implementation should align with the existing TimeSolution model tables and coding standards.

The important design point is that FFT components are model items, not raw events.

---

## Possible future workflow

A future FFT workflow could look like this:

1. Select an event stream from the Event Ensemble.
2. Require `@ByCase = 0`.
3. Require an `@EventSet` with one primary event.
4. Select a numeric metric from event-level properties.
5. Apply case and event property filters.
6. Retrieve the ordered signal for the selected time window.
7. Regularize the signal if needed.
8. Run FFT.
9. Rank components by amplitude or power.
10. Store the model header with `Models.ModelType = 'FFT'`.
11. Store spectral components as model items.
12. Compare FFT components across models to find possible common drivers.

---

## Example use cases

| Domain        | Signal                   | Possible shared driver                              |
| ------------- | ------------------------ | --------------------------------------------------- |
| IoT           | Temperature readings     | Daily heat cycle, HVAC schedule, weather            |
| Manufacturing | Vibration readings       | Machine wear, shift pattern, maintenance schedule   |
| Retail        | Sales by day             | Seasonality, paydays, promotions, holidays          |
| Healthcare    | Patient arrivals by hour | Staffing cycles, local events, flu season           |
| Finance       | Daily closing prices     | Market cycles, sector effects, macroeconomic cycles |
| Web analytics | Traffic by hour          | User behavior, campaign timing, bot activity        |

In each case, the point is not merely to identify cycles. The point is to find matching cycles across signals that may otherwise appear unrelated.

---

## How this supports Time Molecules

FFT models add another kind of reusable analytical structure to the Time Molecules ecosystem.

Markov models capture transition structure:

```text
A -> B -> C
```

FFT models capture cyclical structure:

```text
signal = cycle1 + cycle2 + cycle3 + residual
```

Both structures can be stored, compared, linked, and reasoned over.

This supports the broader Time Molecules goal:

> Move beyond static facts and isolated metrics toward reusable structures that describe how things unfold over time.

---

## Summary

FFT can be handled from the Event Ensemble as a traditional time-based analysis.

The current Time Molecules structure can retrieve the relevant event sequence and metric values, especially when:

```text
@ByCase = 0
@EventSet = one event type
@Metric = selected event-level numeric value
```

A future implementation can store FFT results as a model:

```text
Models.ModelType = 'FFT'
```

The model items would store spectral components such as:

```text
frequency
amplitude
phase
rank
period
```

The main value is component similarity. If two signals share similar frequency, amplitude, and phase, they may have a common driver. This does not prove causation, but it gives human analysts and AI agents a powerful clue.

In conventional Time Molecules terms:

> Markov models help compare event-flow structure.
> FFT models help compare cyclical signal structure.

Together, they expand Time Molecules as the time-side of BI.

```
```
