# HIV Prevention Outcomes and Data Reliability

An independent R portfolio project examining 
(1) post-peak HIV incidence trajectories. 
(2) associations between maternal ART coverage and pediatric HIV infections. 
(3) sensitivity of epidemic-progress conclusions to UNAIDS versus IHME estimates 
and uncertainty. Includes a separate audit of AI-assisted R code using synthetic 
edge cases.

## Data Availability

The original UNAIDS, IHME, and Our World in Data datasets
are not included in this repository because redistribution
permissions have not been established for all sources.

See [data/SOURCES.md] for source URLs,
indicator definitions, data preparation instructions,
and methodological limitations.

The analyses and Shiny application require locally prepared
source files before they can run.

## Reproduce
1. Install R and RStudio. Install packages with 
`install.packages(c('tidyverse','readxl','rmarkdown','knitr','shiny'))`.
2. Put the UNAIDS workbook and three IHME Both CSV files in `data/`; 
run `source('prepare_source_data.R')`. Download the remaining maternal ART
and pediatric indicators and prepare `data/unaids_incidence.csv`, 
`data/ihme_incidence.csv`, `data/maternal_art.csv`, and 
`data/pediatric_infections.csv`. Each requires `country,year,value`. 
Follow `data/SOURCES.md` and verify definitions; do not simply 
rename unrelated indicators.
3. Run `source('source_sensitivity.R')` independently to 
verify source analysis. 
Once maternal/pediatric inputs exist, run `source('analysis.R')` 
for all analyses.
4. Run `source('ai_validation.R')`.
5. Knit `hiv.Rmd` to HTML or use `rmarkdown::render('hiv.Rmd')`.
6. Run `shiny::runApp('app.R')`.

## Methodological choices
- Countries: Kenya, South Africa, Uganda.
- Real input files must contain at most one observation per country-year. 
Duplicates stop the workflow.
- Maternal ART lag: 0–3 years; 2-year lag is the prespecified illustration, 
not a proven biological delay.
- Models are observational and ecological, not causal.
- Missing source values are not imputed. Each analysis writes a completeness report.
- Source disagreement does not establish which estimate is correct.

## AI use
ChatGPT was used for coding suggestions, debugging, and project organization. 
For AI-Validation, AI-generated code from ChatGPT was tested with 
synthetic edge cases, and scientific interpretation and data-source 
verification require independent review. 

## Files
- `analysis.R`: data joins, figures, descriptive summaries, 
regression models, and quality audit
- `ai_validation.R`: synthetic edge-case tests and corrected 
percentage-change function
- `hiv.Rmd`: reproducible narrative report
- `app.R`: Shiny dashboard
- `data/SOURCES.md`: source provenance checklist
- `outputs/` and `figures/`: generated files (not included until the data are run)

## Scope
This is an epidemiological data analysis.

## Source sensitivity scope
The 1990–2016 source analysis uses annual **counts**, not incidence rates; 
interval overlap and endpoint-bound stress tests are descriptive, not 
formal inference. `source_sensitivity.R` can run without maternal ART files.
