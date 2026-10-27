
# AI-ASSISTED CODE VALIDATION
# All test values below are synthetic, not actual HIV data.

# Purpose:
# 1. Reproduce the structure of ChatGPT's original code.
# 2. Test its behavior with synthetic edge cases.
# 3. Test the corrected approach.
# 4. Compare results with independently specified expectations.

library(dplyr)
library(tidyr)
library(readr)

dir.create("outputs", showWarnings = FALSE)


# STEP 1: Synthetic test data


test_data <- tibble(
  country = c("A", "A", "B", "B", "C", "C",
              "D", "D", "D", "E", "E"),
  year = c(1990, 2024, 1990, 2024, 1990, 2024,
           1990, 2024, 2024, 2020, 2024),
  infections = c(100, 75, 0, 50, NA, 30,
                 100, 80, 90, 40, 30)
)

test_countries <- c("A", "B", "C", "D", "E")

# Expected percentage changes:
# A: -25%, B: NA (zero baseline)
# C: NA (missing baseline)
# D: -15% (mean of 80 and 90 is 85)
# E: NA (1990 observation absent)

expected <- tibble(
  country = test_countries,
  expected_change = c(-25, NA, NA, -15, NA)
)


# STEP 2: Original AI-generated approach

# Adapted from the original ChatGPT response.
# The original retained n_observations during pivot_wider().

original_ai_code <- function(data, countries) {
  
  data |>
    filter(
      country %in% countries,
      year %in% c(1990, 2024)
    ) |>
    group_by(country, year) |>
    summarise(
      infections = if (all(is.na(infections))) {
        NA_real_
      } else {
        mean(infections, na.rm = TRUE)
      },
      n_observations = n(),
      .groups = "drop"
    ) |>
    pivot_wider(
      names_from = year,
      values_from = infections,
      names_prefix = "infections_"
    ) |>
    right_join(
      tibble(country = countries),
      by = "country"
    ) |>
    mutate(
      percent_change = case_when(
        is.na(infections_1990) |
          is.na(infections_2024) ~ NA_real_,
        infections_1990 == 0 ~ NA_real_,
        TRUE ~
          (infections_2024 - infections_1990) /
          infections_1990 * 100
      )
    ) |>
    select(
      country,
      infections_1990,
      infections_2024,
      percent_change
    )
}

# Run the original approach.
original_result <- original_ai_code(
  test_data,
  test_countries
)

cat("\nORIGINAL AI CODE RESULTS\n")
print(original_result)

# Check whether the original code returns exactly
# one row for each requested country.
original_row_check <- original_result |>
  count(country, name = "rows_returned")

cat("\nORIGINAL CODE ROW COUNTS\n")
print(original_row_check)


# STEP 3: Corrected approach

# The correction removes n_observations before pivoting.
# It also ensures both endpoint columns exist, even if
# an endpoint year is absent from the test dataset.

corrected_code <- function(data, countries) {
  
  aggregated <- data |>
    filter(
      country %in% countries,
      year %in% c(1990, 2024)
    ) |>
    group_by(country, year) |>
    summarise(
      infections = if (all(is.na(infections))) {
        NA_real_
      } else {
        mean(infections, na.rm = TRUE)
      },
      n_observations = n(),
      .groups = "drop"
    )
  
  wide <- aggregated |>
    select(country, year, infections) |>
    mutate(
      year = factor(year, levels = c(1990, 2024))
    ) |>
    pivot_wider(
      names_from = year,
      values_from = infections,
      names_prefix = "infections_",
      names_expand = TRUE
    )
  
  tibble(country = countries) |>
    left_join(wide, by = "country") |>
    mutate(
      percent_change = case_when(
        is.na(infections_1990) |
          is.na(infections_2024) ~ NA_real_,
        infections_1990 == 0 ~ NA_real_,
        TRUE ~
          (infections_2024 - infections_1990) /
          infections_1990 * 100
      )
    )
}

corrected_result <- corrected_code(
  test_data,
  test_countries
)

cat("\nCORRECTED CODE RESULTS\n")
print(corrected_result)


# STEP 4: Compare corrected output with expectations


checks <- expected |>
  left_join(
    corrected_result |>
      select(country, percent_change),
    by = "country"
  ) |>
  mutate(
    passed = case_when(
      is.na(expected_change) &
        is.na(percent_change) ~ TRUE,
      
      !is.na(expected_change) &
        !is.na(percent_change) ~
        abs(expected_change - percent_change) < 1e-6,
      
      TRUE ~ FALSE
    )
  )

cat("\nVALIDATION CHECKS\n")
print(checks)

stopifnot(
  nrow(corrected_result) == length(test_countries),
  n_distinct(corrected_result$country) ==
    length(test_countries),
  all(checks$passed)
)

# Check original code's reported Country D issue.
original_d <- original_result |>
  filter(country == "D")

stopifnot(
  nrow(original_d) == 2,
  all(is.na(original_d$percent_change))
)

# Check that the corrected code returns one D row.
corrected_d <- corrected_result |>
  filter(country == "D")

stopifnot(
  nrow(corrected_d) == 1,
  corrected_d$percent_change == -15
)

# Check the synthetic inputs are nonnegative.
stopifnot(
  all(test_data$infections >= 0, na.rm = TRUE)
)

write_csv(checks, "outputs/ai_validation_checks.csv")
write_csv(original_result, "outputs/ai_original_results.csv")
write_csv(corrected_result, "outputs/ai_corrected_results.csv")

message("All corrected-code synthetic validation checks passed.")
