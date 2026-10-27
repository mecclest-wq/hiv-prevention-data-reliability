# HIV epidemiology portfolio | Main analysis
# Run from the project root after adding the CSV files to data/.
# Each CSV needs: country, year, value (one row per country-year).

library(tidyverse)
library(readxl)
library(rmarkdown)
library(knitr)
library(shiny)


countries <- c('Kenya', 'South Africa', 'Uganda')
dir.create('outputs', showWarnings = FALSE)
dir.create('figures', showWarnings = FALSE)

# Data sources must be checked before joining: do not silently average duplicates.
read_indicator <- function(path, variable) {
  if (!file.exists(path)) stop('Missing input file: ', path)
  x <- read_csv(path, show_col_types = FALSE)
  required <- c('country', 'year', 'value')
  if (!all(required %in% names(x))) stop(path, ' needs country, year, value columns')
  x <- x |>
    transmute(country = as.character(country),
              year = as.integer(year),
              value = as.numeric(value)) |>
    filter(country %in% countries)
  duplicates <- x |> count(country, year) |> filter(n > 1)
  if (nrow(duplicates) > 0) stop('Duplicate country-year values in ', path,
                                '. Inspect the source; do not average estimates automatically.')
  if (any(x$value < 0, na.rm = TRUE)) stop('Negative values found in ', path)
  x |> rename(!!variable := value)
}

# INPUT DEFINITIONS:
# unaids_incidence.csv: UNAIDS estimated annual new HIV infections, all ages, counts,
# ihme_incidence.csv: IHMEestimated annual new HIV infections, all ages, counts
# maternal_art.csv: percent (0-100) of pregnant women living with HIV receiving ART
# pediatric_infections.csv: estimated annual new HIV infections ages 0-14, counts
# The incidence files must measure the SAME construct and age range.

unaids <- read_indicator('data/unaids_incidence.csv', 'infections_unaids')
ihme <- read_indicator('data/ihme_incidence.csv', 'infections_ihme')
art <- read_indicator('data/maternal_art.csv', 'art_percent')
children <- read_indicator('data/pediatric_infections.csv', 'child_infections')
if (any(art$art_percent > 100, na.rm = TRUE)) stop('ART coverage exceeds 100%; check units')

# A: POST-PEAK TRAJECTORIES (UNAIDS estimates only)
# A peak is the largest observed estimate.
peaks <- unaids |>
  filter(!is.na(infections_unaids)) |>
  group_by(country) |>
  arrange(year, .by_group = TRUE) |>
  slice_max(infections_unaids, n = 1, with_ties = TRUE) |>
  slice_min(year, n = 1, with_ties = FALSE) |>
  transmute(peak_year = year, peak_infections = infections_unaids) |>
  ungroup()

post_peak <- unaids |>
  left_join(peaks, by = 'country') |>
  filter(!is.na(peak_year), year >= peak_year) |>
  mutate(years_since_peak = year - peak_year,
         percent_of_peak = if_else(peak_infections > 0,
                                   100 * infections_unaids / peak_infections, NA_real_))

post_peak_summary <- post_peak |>
  group_by(country) |>
  summarise(peak_year = first(peak_year),
            peak_infections = first(peak_infections),
            last_year = max(year[!is.na(infections_unaids)]),
            n_observed = sum(!is.na(infections_unaids)),
            .groups = 'drop')

p_peak <- ggplot(post_peak, aes(years_since_peak, percent_of_peak, color = country)) +
  geom_line(linewidth = 1, na.rm = TRUE) +
  geom_hline(yintercept = 100, linetype = 'dashed', color = 'gray60') +
  labs(title = 'Figure 1: HIV infections relative to each country’s observed peak',
       subtitle = 'Peak = 100%; different countries can have different peak years',
       x = 'Years since observed peak', y = 'Infections as % of peak', color = 'Country',
       caption = 'Source: UNAIDS estimates via OWID; see data sources') +
  theme_minimal()
ggsave('figures/post_peak.png', p_peak, width = 8, height = 5, dpi = 160)
write_csv(post_peak, 'outputs/post_peak.csv')
write_csv(post_peak_summary, 'outputs/post_peak_summary.csv')

# B: MATERNAL ART COVERAGE AND PEDIATRIC HIV
# This analysis examines associations, not causal effects.
# Maternal ART coverage is matched with pediatric HIV infections
# in the same year or 1, 2, or 3 years later.
# For example, a two-year lag pairs ART coverage in 2000
# with pediatric infections in 2002.
# The join uses actual calendar years and does not create
# infection estimates for years missing from the dataset.
make_lag_data <- function(lag_years) {
  art |>
    mutate(outcome_year = year + lag_years) |>
    rename(art_year = year) |>
    left_join(children, by = c('country', 'outcome_year' = 'year')) |>
    mutate(lag_years = lag_years,
           included = !is.na(art_percent) & !is.na(child_infections),
           exclusion_reason = case_when(
             is.na(art_percent) ~ 'ART coverage missing',
             is.na(child_infections) ~ 'Pediatric infections missing for outcome year',
             TRUE ~ 'Included'
           ))
}

lag_data <- bind_rows(lapply(0:3, make_lag_data))
lag_quality <- lag_data |>
  group_by(country, lag_years, exclusion_reason) |>
  summarise(n_country_years = n(), .groups = 'drop')
write_csv(lag_data, 'outputs/maternal_lag_data.csv')
write_csv(lag_quality, 'outputs/maternal_data_quality.csv')

# A two-year lag is a prespecified example, not an optimized lag.
# Review alternative lags as sensitivity checks, not as evidence of causality.
model_data <- lag_data |> filter(lag_years == 2, included)

# Only fit models when there are enough complete observations and variation.
model_results <- tibble(model = character(), term = character(), estimate = double(),
                        std_error = double(), p_value = double(), n = integer())
if (nrow(model_data) >= 12 && n_distinct(model_data$art_percent) >= 3 &&
    n_distinct(model_data$country) >= 2 && n_distinct(model_data$outcome_year) >= 3) {
  # Log1p allows zero infection counts; coefficients are associations on the log scale.
  model_data <- model_data |> mutate(log_child_infections = log1p(child_infections))
  unadjusted <- lm(log_child_infections ~ art_percent, data = model_data)
  adjusted <- lm(log_child_infections ~ art_percent + country + outcome_year,
                 data = model_data)
  # Coefficients may be unstable if sample size is small or predictors are collinear.
  extract_model <- function(fit, label) {
    co <- summary(fit)$coefficients
    tibble(model = label, term = rownames(co), estimate = co[, 1],
           std_error = co[, 2], p_value = co[, 4], n = nobs(fit))
  }
  model_results <- bind_rows(extract_model(unadjusted, 'Unadjusted'),
                             extract_model(adjusted, 'Country + linear year adjusted'))
} else {
  message('Insufficient complete data or variation for the prespecified regression models.')
}
write_csv(model_results, 'outputs/maternal_model_results.csv')
# Sensitivity check: within-country annual changes
# Uses the same log1p transformation as the primary model.
# Consecutive years only; does not imply causality.

first_difference_data <- model_data |>
  arrange(country, outcome_year) |>
  group_by(country) |>
  mutate(
    year_gap = outcome_year - lag(outcome_year),
    change_log_infections =
      log1p(child_infections) -
      lag(log1p(child_infections)),
    change_art = art_percent - lag(art_percent)
  ) |>
  ungroup() |>
  filter(
    year_gap == 1,
    !is.na(change_log_infections),
    !is.na(change_art)
  )

if (nrow(first_difference_data) >= 12 &&
    n_distinct(first_difference_data$change_art) >= 3) {
  
  difference_model <- lm(
    change_log_infections ~ change_art,
    data = first_difference_data
  )
  
  print(summary(difference_model))
  
} else {
  message("Insufficient data for first-difference sensitivity check.")
}
# Compare the adjusted ART association across all four lags.

lag_model_results <- bind_rows(lapply(0:3, function(k) {
  
  d <- lag_data |>
    filter(lag_years == k, included) |>
    mutate(log_child_infections = log1p(child_infections))
  
  if (nrow(d) < 12 ||
      n_distinct(d$art_percent) < 3 ||
      n_distinct(d$country) < 2 ||
      n_distinct(d$outcome_year) < 3) {
    return(tibble(
      lag_years = k,
      n = nrow(d),
      art_coefficient = NA_real_
    ))
  }
  
  fit <- lm(
    log_child_infections ~ art_percent + country + outcome_year,
    data = d
  )
  
  tibble(
    lag_years = k,
    n = nobs(fit),
    art_coefficient = unname(coef(fit)["art_percent"])
  )
}))

print(lag_model_results)

write_csv(
  lag_model_results,
  "outputs/maternal_lag_model_results.csv"
)

p_art <- ggplot(
  model_data,
  aes(
    x = art_percent,
    y = child_infections,
    color = country
  )
) +
  geom_point(alpha = 0.75, size = 2) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = FALSE,
    linewidth = 1
  ) +
  labs(
    title = "Figure 2: Maternal ART coverage and subsequent pediatric HIV infections",
    subtitle = "ART coverage compared with pediatric infections two years later",
    x = "Maternal ART coverage (%)",
    y = "Estimated annual pediatric HIV infections (count)",
    color = "Country",
    caption = paste(
      "Each point represents one matched pair of country-years.",
      "Lines show unadjusted country-specific linear trends, not causal effects."
    )
  ) +
  theme_minimal()

ggsave(
  "figures/maternal_art_lag.png",
  p_art,
  width = 8,
  height = 5,
  dpi = 160
)


# C: SOURCE SENSITIVITY AND ESTIMATION UNCERTAINTY
# Independent script also runs without the maternal ART input files.
source('source_sensitivity.R')

# Explicit data-quality audit for the README/report.
quality_overview <- tibble(
  analysis = c('Post-peak (UNAIDS)', 'Maternal ART / pediatric HIV (2-year lag)',
               'UNAIDS vs IHME matched 1990–2016 estimates'),
  total_rows = c(nrow(unaids), nrow(lag_data |> filter(lag_years == 2)),
                 nrow(paired)),
  complete_rows = c(sum(!is.na(unaids$infections_unaids)),
                    nrow(model_data), sum(paired$complete_point)),
  excluded_rows = total_rows - complete_rows
)
write_csv(quality_overview, 'outputs/quality_overview.csv')
print(quality_overview)
message('Analysis complete. Check outputs/ and figures/ before interpreting results.')
