# Data Sources and Reproducibility

## Data availability and redistribution

This repository contains original analysis code and documentation for an 
independent HIV epidemiology project examining Kenya, South Africa, and Uganda.

Third-party source datasets and processed copies of those datasets are
intentionally excluded from this public repository. 
Redistribution permission has not been established for every 
source. Users should obtain data directly from the respective 
providers and comply with the applicable terms of use.

The absence of these files means the analyses and Shiny application cannot run immediately after cloning the repository. Reproduction requires obtaining the specified datasets and preparing them in the expected format.

## Sources used

### 1. UNAIDS — Annual new HIV infections

- **Source:** UNAIDS HIV estimates workbook
- **Source page:** 
https://www.unaids.org/en/resources/documents/2026/HIV_estimates_with_uncertainty_bounds_1990-present
- **Original local filename:** 
`HIV_estimates_from_1990-to-present_1.xlsx`
- **Worksheet:** `HIV2026Estimates_ByYear`
- **Indicator:** Adults and children newly infected with HIV
- **Population:** All ages, both sexes
- **Unit:** Estimated annual number of new infections
- **Analysis period:** 1990–2016 for source comparison; 
broader available years for longitudinal analysis
- **Extraction:** Original worksheet data beginning at row 7; 
columns 49–51 contain the estimate and uncertainty bounds, 
according to the extraction used for this project
- **Limitations:** Estimates may be rounded; censored values 
are treated as missing
- **Download date:** Record the actual date from the original 
download

### 2. IHME — HIV/AIDS incidence estimates

- **Source:** Institute for Health Metrics and Evaluation 
(IHME), HIV trends interface
- **Source page:** 
https://hiv.ihme.services/trends?age_group_id=22&cause_id=298&gender_id=3&location_id=190&measure_id=6&metric_id=1
- **Original files:** Separate exports for Kenya, South Africa, 
and Uganda
- **Indicator:** HIV/AIDS incidence, number of new cases
- **Population:** All ages, both sexes
- **Unit:** Estimated annual number of new infections
- **Analysis period:** 1990–2016
- **Fields:** `Both genders Value`, `Both genders Lower Bound`, 
`Both genders Upper Bound`
- **GBD study/release:** Verify against the original export or 
accompanying metadata
- **Download date:** Record the actual date from the original
download

### 3. Our World in Data — New HIV infections

- **Source:** UNAIDS estimates, presented through Our World in 
Data
- **Indicator page:** 
https://ourworldindata.org/grapher/number-of-new-hiv-infections-per-year
- **Original local filename:** 
`number-of-new-hiv-infections-per-year.csv`
- **Unit:** Estimated annual number of new HIV infections
- **Data version:** Record the source release and retrieval 
date used for the project
- **Note:** This series may differ from estimates in the 
separately downloaded UNAIDS workbook because of data-release 
or processing differences.

### 4. Our World in Data — Maternal ART coverage

- **Source:** UNAIDS estimates via the World Bank, presented 
through Our World in Data
- **Indicator page:** 
https://ourworldindata.org/grapher/art-coverage-for-pregnant-women
- **Original local filename:** 
`art-coverage-for-pregnant-women.csv`
- **Indicator:** Percentage of pregnant women living with 
HIV receiving antiretroviral medicine for prevention of 
mother-to-child transmission
- **Unit:** Percent (0–100)
- **Published indicator coverage:** 2000–2024
- **Note:** This is a coverage estimate, not a direct count of 
women receiving treatment.

### 5. Our World in Data — Children newly infected with HIV

- **Source page:**
https://ourworldindata.org/grapher/share-of-children-under-fifteen-years-old-with-hiv
- **Original local filename:** 
`share-of-children-under-fifteen-years-old-with-hiv.csv`
- **Indicator:** Children newly infected with HIV
- **Unit and age definition:** Verify against the exact
downloaded dataset metadata
- **Download date:** Record the actual date from the original 
download
- **Important:** Confirm that the downloaded values represent 
annual new infections rather than a percentage, prevalence, 
or another indicator before reproducing the regression analysis.

## Local data preparation

The project uses standardized local inputs with the following 
structure:

| Column | Description |
|---|---|
| `country` | Country name |
| `year` | Calendar year |
| `value` | Numeric indicator estimate |

For applicable datasets:

1. Download the specified original source file.
2. Confirm the indicator definition, unit, population, and 
data release.
3. Filter to Kenya, South Africa, and Uganda.
4. Preserve the actual observation years and missing values.
5. Create the standardized inputs required by the analysis 
scripts.
6. Preserve lower and upper uncertainty bounds where required 
for source comparisons.

The source-sensitivity analysis requires additional 
uncertainty-bound columns or their equivalent in the original 
source files.

Do not substitute incidence rates for infection counts, or 
percentages for counts, without explicitly changing the 
analytical method.

## Methodological limitations

UNAIDS and IHME estimates are model-based and may differ 
because of modeling assumptions, data inputs, and release 
versions.

Maternal ART coverage and pediatric HIV infection estimates 
may share underlying modeling inputs. Regression associations 
may also reflect secular trends, autocorrelation, and other 
unmeasured factors. The project does not establish a causal 
effect of maternal ART coverage on pediatric infections.

The 1990–2016 source comparison uses a shared observation 
window. Observed peaks at the start of the window are boundary 
observations and do not necessarily represent historical 
epidemic maxima.

## Licensing and attribution

All original datasets remain the property of their respective 
data providers and are subject to applicable licensing and 
usage terms.

This repository does not grant redistribution rights to 
any third-party data. Users are responsible for consulting 
the providers' current licensing requirements before 
downloading, using, or sharing the datasets.

Source attribution is provided for research transparency 
and does not imply endorsement by UNAIDS, IHME, or Our World 
in Data.