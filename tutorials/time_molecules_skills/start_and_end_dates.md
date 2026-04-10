# How to use `dbo.TimeIntelligenceWindow` to set `StartDateTime` and `EndDateTime`

`dbo.TimeIntelligenceWindow(@AsOfDateTime, @Units, @FuncCode)` returns one row with `WindowStart` and `WindowEnd`. It exists so agents can generate consistent date ranges first, then feed those dates into the major TimeSolution patterns that use `@StartDateTime` and `@EndDateTime`. The function is inline, returns `FuncCode`, `AsOfDateTime`, `Units`, `WindowStart`, `WindowEnd`, `WindowLabel`, and `Grain`, and documents that `WindowEnd` is exclusive.

## Why this matters

In Time Molecules, the date range is one of the most important parts of a query or model definition.

* information goes stale
* processes drift over time
* many useful comparisons differ only by time
* broad date ranges hurt performance
* many major functions use `@StartDateTime` and `@EndDateTime`

So a good default agent behavior is:

1. choose the time window first
2. materialize `WindowStart` and `WindowEnd`
3. pass those values into model, sequence, or event queries

Using “begin of time to end of time” is usually a poor choice both analytically and operationally.

## Parameters

### `@AsOfDateTime`

The reference datetime. Everything is anchored to this value. If you ask for `MTD`, it means month-to-date relative to this datetime, not relative to now unless you pass `GETDATE()`.

### `@Units`

Used differently depending on the code.

* ignored for many current-period and to-date codes
* shift count for `LAG*` and `LEAD*`
* rolling window length for `ROLLING*`
* number of periods included for `NMTD`, `NQTD`, `NYTD`

### `@FuncCode`

The time-intelligence code that determines the type of window. Supported families include:

* current period: `HOUR`, `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`
* to-date: `DTD`, `WTD`, `MTD`, `QTD`, `YTD`
* previous full period: `PREVHOUR`, `PREVDAY`, `PREVWEEK`, `PREVMONTH`, `PREVQTR`, `PREVYEAR`
* next full period: `NEXTHOUR`, `NEXTDAY`, `NEXTWEEK`, `NEXTMONTH`, `NEXTQTR`, `NEXTYEAR`
* lag full period: `LAGHOUR`, `LAGDAY`, `LAGWEEK`, `LAGMONTH`, `LAGQTR`, `LAGYEAR`
* lead full period: `LEADHOUR`, `LEADDAY`, `LEADWEEK`, `LEADMONTH`, `LEADQTR`, `LEADYEAR`
* rolling trailing window: `ROLLINGHOURS`, `ROLLINGDAYS`, `ROLLINGWEEKS`, `ROLLINGMONTHS`, `ROLLINGQUARTERS`, `ROLLINGYEARS`
* multi-period-to-date: `NMTD`, `NQTD`, `NYTD`

## Most important combinations

### Current full period

Use these when you want the complete containing period.

* `('2026-04-10 09:30', 0, 'DAY')` → current full day
* `('2026-04-10 09:30', 0, 'MONTH')` → current full month
* `('2026-04-10 09:30', 0, 'QUARTER')` → current full quarter

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 0, 'MONTH');
```

### To-date period

Use these when you want the start of the period through the `@AsOfDateTime`.

* `DTD` = day to date
* `WTD` = week to date
* `MTD` = month to date
* `QTD` = quarter to date
* `YTD` = year to date

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 0, 'MTD');
```

This is especially useful when current-period data is still accumulating.

### Previous full period

Use these for clean comparisons with the immediately prior complete period.

* `PREVDAY`
* `PREVWEEK`
* `PREVMONTH`
* `PREVQTR`
* `PREVYEAR`

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 0, 'PREVMONTH');
```

Good pattern: compare `PREVMONTH` versus `MONTH`, or `PREVQTR` versus `QUARTER`.

### Next full period

Use these for planning or forward-looking windows.

* `NEXTDAY`
* `NEXTWEEK`
* `NEXTMONTH`
* `NEXTQTR`
* `NEXTYEAR`

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 0, 'NEXTQTR');
```

### Lag full period

Use these when you want a clean shifted period, not a rolling range.

* `LAGDAY, 7` = the day seven days back
* `LAGMONTH, 3` = the full month three months back
* `LAGYEAR, 1` = prior year as a full year window

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 7, 'LAGDAY');
```

Meaning: a single full day window shifted back seven days.

### Lead full period

Mirror image of lag.

* `LEADDAY, 7`
* `LEADMONTH, 1`
* `LEADQTR, 2`

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 2, 'LEADQTR');
```

The sample metadata includes this exact pattern.

### Rolling trailing windows

Use these when you want trailing ranges ending exactly at `@AsOfDateTime`.

* `ROLLINGDAYS, 7` = trailing 7 days
* `ROLLINGHOURS, 24` = trailing 24 hours
* `ROLLINGMONTHS, 12` = trailing 12 months

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 30, 'ROLLINGDAYS');
```

This is usually better than “current month” when you want a stable length.

### Multi-period-to-date

Use these when you want several periods including the current one, ending at `@AsOfDateTime`.

* `NMTD, 3` = three months to date
* `NQTD, 2` = two quarters to date
* `NYTD, 5` = five years to date

Example:

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 3, 'NMTD');
```

Meaning: from the start of the month two months before the current month through now.

## Recommended patterns for TimeSolution

### Pattern 1: get the window first, then query events

```sql
SELECT e.*
FROM dbo.EventsFact e
CROSS APPLY dbo.TimeIntelligenceWindow(GETDATE(), 1, 'PREVMONTH') ti
WHERE e.EventDate >= ti.WindowStart
  AND e.EventDate <  ti.WindowEnd;
```

This usage is explicitly documented in the TVF metadata.

### Pattern 2: use two windows to compare two models that differ only by time

This is one of the most important Time Molecules patterns.

For example:

* model A: `PREVMONTH`
* model B: `MONTH`

or:

* model A: `QTD`
* model B: `PREVQTR`

or:

* model A: `ROLLINGDAYS, 30`
* model B: `ROLLINGDAYS, 30` anchored one month earlier

The point is to keep event set, transforms, filters, and metric the same, and vary only the time window.

### Pattern 3: prefer bounded windows over “all history”

Usually avoid:

* very old data mixed with current data
* giant date windows by default
* unconstrained model creation

Why:

* process behavior changes
* business rules change
* operational patterns drift
* large windows cost more to compute
* comparisons become less meaningful

## Practical examples

### Last complete month

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 0, 'PREVMONTH');
```

### Month to date

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 0, 'MTD');
```

### Trailing 90 days

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 90, 'ROLLINGDAYS');
```

### Same weekday one week back

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 7, 'LAGDAY');
```

### Previous full quarter

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 0, 'PREVQTR');
```

### Two quarters ahead

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 2, 'LEADQTR');
```

### Three months to date

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow('2026-04-10T09:30:00', 3, 'NMTD');
```

### Rolling 24 hours

```sql
SELECT *
FROM dbo.TimeIntelligenceWindow(GETDATE(), 24, 'ROLLINGHOURS');
```

## What the output means

* `WindowStart` is inclusive
* `WindowEnd` is exclusive
* `WindowLabel` is a readable description
* `Grain` tells you the dominant level such as `DAY`, `MONTH`, `YEAR`, or `ROLLING`

That exclusive `WindowEnd` is important. Use:

```sql
WHERE EventDate >= WindowStart
  AND EventDate <  WindowEnd
```

not `<= WindowEnd`.

## Good agent defaults

* use `MTD`, `QTD`, `YTD` for current reporting snapshots
* use `PREV*` for clean prior-period comparison
* use `ROLLING*` for stable trailing horizons
* use `LAG*` and `LEAD*` for exact shifted-period logic
* use `NMTD`, `NQTD`, `NYTD` when you want several periods ending now
* pick the time window before building the model

## Source material

This skill is based on the tabe-valued function, `dbo.TimeIntelligenceWindow`, which includes its metadata JSON, supported function codes, parameter meanings, sample calls, inline implementation, and exclusive `WindowEnd` rule.
