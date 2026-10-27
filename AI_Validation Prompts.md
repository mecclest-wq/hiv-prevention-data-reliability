# AI-Assisted Code Validation: Prompt and Response Log

## Purpose

I used ChatGPT to help develop R code for calculating percentage changes in 
estimated annual new HIV infections. I then examined the generated code 
using synthetic data to test its handling of missing values, zero baselines, 
and duplicate country-year observations.

This validation was conducted independently of the real HIV estimates. The 
synthetic duplicate records were created to test the code's reliability; 
duplicate country-year observations were not identified in the real dataset 
used for the project.

## Prompt 1: Initial code generation

**My prompt:**

> Write R code using `dplyr` to calculate the percentage change in estimated 
annual new HIV infections between 1990 and 2024 for Kenya, South Africa, and 
Uganda.
>
> My dataset is named `hiv_clean` and contains `country`, `year`, and 
`infections`.
>
> The code should handle missing baseline values, zero baseline values, 
and duplicate country-year observations. Explain any assumptions. Do not 
invent numerical results.

**ChatGPT's response:**

ChatGPT generated a workflow using `filter()`, `group_by()`, `summarise()`, 
`pivot_wider()`, `right_join()`, and `mutate()`.

It proposed averaging comparable duplicate country-year estimates, returning 
`NA` for missing or zero baselines, and retaining requested countries even 
when data were missing.

However, the original code retained `n_observations` during `pivot_wider()`. 
This introduced an additional grouping identifier during reshaping and could 
produce multiple rows for one country.

The original code structure is reproduced in `ai_validation.R`.

## Prompt 2: Reported synthetic test failure

**My prompt:**

> I tested your original R code using synthetic data containing duplicate 
country-year observations. For Country D, the data contain one 1990 
observation (100 infections) and two 2024 observations
(80 and 90 infections). Your code produced two rows for Country D with
NA percentage changes instead of one row. Please identify the cause of this 
issue, revise your original code to fix it, and explain your changes. Keep 
the duplicate-handling assumption explicit and do not invent results from my 
real HIV dataset.

**ChatGPT's response:**

ChatGPT revised the code by separating filtering, aggregation, reshaping, and 
percentage-change calculation into distinct steps. The revised version omitted 
`n_observations` from the reshaping input. However, its explanation did not 
precisely identify the original problem. It suggested that duplicate 
observations might not have been aggregated, even though the original code 
already used `group_by(country, year)` and `summarise()`.My code review 
identified the more specific issue: retaining `n_observations` caused 
`pivot_wider()` to treat different observation counts as distinct row 
identifiers.

## Validation results

I evaluated the original and corrected approaches using synthetic cases:

| Test country | Condition | Expected percentage change |
|---|---|---:|
| A | 100 infections in 1990; 75 in 2024 | -25% |
| B | Zero 1990 baseline | NA |
| C | Missing 1990 estimate | NA |
| D | Duplicate 2024 values of 80 and 90, with 1990 baseline of 100 | -15% |
| E | No 1990 observation | NA |

The corrected approach also ensures that both endpoint columns are available 
when an endpoint year is absent. The executable checks and output tables are 
in `ai_validation.R` and the `outputs` folder.

## Assumptions and limitations

For the synthetic duplicate test, I assumed multiple values for the same country 
and year represent comparable estimates of the same quantity and used their 
arithmetic mean. This is a test assumption, not a claim about the real HIV 
dataset. The percentage-change calculation compares estimated annual infection 
counts, not incidence rates. The validation tests code behavior; it does not 
establish that the underlying epidemiological estimates are accurate.

## AI use disclosure

ChatGPT was used to generate an initial R workflow and suggest a revised 
implementation. I evaluated its behavior with synthetic tests, investigated 
the reshaping problem, and documented the corrected workflow. I did not use 
synthetic test results as evidence of actual HIV trends.

**Original conversation:** See `OG AI Code Validation Conversation.pdf` for the initial 
prompts and full ChatGPT responses.
