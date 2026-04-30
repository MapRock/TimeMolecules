
# Calculate Stationary Distribution of a Markov Model

## Overview

The **stationary distribution** (also called the steady-state or long-run probability distribution) gives the long-term proportion of time the process will spend in each state (event), assuming the Markov chain runs forever.

This concept is introduced in the book *Time Molecules* on **page 49** (“Stationary distribution”).

The calculation is performed by the single utility function `stationary_distribution()` inside the book’s central Python module.

**File:** [TimeSolution.py](https://github.com/MapRock/TimeMolecules/blob/main/book_code/src/TimeSolution.py)

This module was intentionally written as one file that can hold many TimeSolution utilities. Right now it contains only the stationary-distribution function; future chapters will add more functions to the same file.

## Purpose

Use this skill when you want to know:
- What is the long-term probability of each event in a stored Markov model?
- Which events will dominate the process over infinite time?

The function reads the transition matrix for a model, computes the stationary distribution, and writes the results into the `dbo.Model_Stationary_Distribution` table.

## Prerequisites

- Full book development environment is installed (`docs/install_timemolecules_dev_env.md`)
- A valid `.env` file with SQL Server connection details
- At least one Markov model already exists in the database (see skill [find_model_id.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_skills/find_model_id.md) if you need a ModelID)

## How to Execute (Direct & Simple)

### Option 1 – Calculate for one specific model (most common)

```python
from TimeSolution import stationary_distribution

# Replace 123 with your actual ModelID
stationary_distribution(ModelID=123)

# Optional: increase iterations for higher precision
stationary_distribution(ModelID=123, iterations=30)
```

### Option 2 – Calculate for **all** models at once (one-liner)

Simply run the script directly from the `book_code/src` folder:

```powershell
python TimeSolution.py
```

This clears the `Model_Stationary_Distribution` table and recomputes the stationary distribution for every model in `vwModels`.

## What the function actually does

1. Retrieves the transition matrix using the stored procedure `[dbo].[ModelMatrix](@ModelID)`
2. Validates that the matrix is square and stochastic
3. Uses power iteration (default 15 iterations) to converge to the stationary distribution
4. Writes one row per event into `dbo.Model_Stationary_Distribution` with columns `ModelID`, `Event`, and `Probability`

## View the Results

```sql
SELECT 
    ModelID,
    Event,
    Probability
FROM dbo.Model_Stationary_Distribution
WHERE ModelID = 123
ORDER BY Probability DESC;
```

## Links

- [TimeSolution.py (full source code)](https://github.com/MapRock/TimeMolecules/blob/main/book_code/src/TimeSolution.py)
- Book reference: *[Time Molecules](https://technicspub.com/time-molecules/)*, page 49 – Stationary distribution

