# Read the original UNAIDS workbook and the three IHME both-sex exports.
library(tidyverse)
library(readxl)

setwd("/cloud/project/hiv_portfolio_project")
getwd()
file.exists("data/HIV_estimates_from_1990-to-present_1.xlsx")

dir.create('data', showWarnings = FALSE)
dir.create('outputs', showWarnings = FALSE)
countries <- c('Kenya', 'South Africa', 'Uganda')

# Source workbook: data start on row 7; column 49=estimate, 50=low, 51=high.
# col_names=FALSE makes columns ...1, ...2, etc.
raw_unaids <- read_excel('data/HIV_estimates_from_1990-to-present_1.xlsx',
                         sheet='HIV2026Estimates_ByYear', skip=6, col_names=FALSE,
                         .name_repair='minimal')
names(raw_unaids) <- paste0('col', seq_along(raw_unaids))
# Values may be strings such as '220 000', '2.5 m', '<500' or '...'.
# Censored values are missing, not converted to arbitrary midpoint values.
parse_unaids <- function(x) {
  x <- trimws(as.character(x))
  x <- gsub('[[:space:]]+', '', x)
  censored <- grepl('^[<>]|^\\.\\.\\.$', x)
  multiplier <- ifelse(grepl('m$', x, ignore.case=TRUE), 1e6,
                ifelse(grepl('k$', x, ignore.case=TRUE), 1e3, 1))
  cleaned <- gsub('[mMkK]$', '', x)
  out <- suppressWarnings(as.numeric(cleaned)) * multiplier
  out[censored] <- NA_real_
  out
}
unaids_bounds <- raw_unaids |>
  transmute(country=as.character(col3), year=as.integer(col1),
            unaids_value=parse_unaids(col49),
            unaids_lower=parse_unaids(col50),
            unaids_upper=parse_unaids(col51)) |>
  filter(country %in% countries, year >= 1990, year <= 2025)
stopifnot(nrow(unaids_bounds |> count(country,year) |> filter(n>1))==0)
stopifnot(all(unaids_bounds$unaids_lower <= unaids_bounds$unaids_value, na.rm=TRUE),
          all(unaids_bounds$unaids_value <= unaids_bounds$unaids_upper, na.rm=TRUE))
write_csv(unaids_bounds, 'data/unaids_incidence_with_bounds.csv')
write_csv(unaids_bounds |> transmute(country,year,value=unaids_value),
          'data/unaids_incidence.csv')

ihme_files <- c(
 'data/Trends, HIV_AIDS Incidence Number in Kenya, All ages, Both, 1990 - 2016.csv',
 'data/Trends, HIV_AIDS Incidence Number in South Africa, All ages, Both, 1990 - 2016.csv',
 'data/Trends, HIV_AIDS Incidence Number in Uganda, All ages, Both, 1990 - 2016.csv')
raw_ihme <- bind_rows(lapply(ihme_files, function(f) read_csv(f, show_col_types=FALSE)))
stopifnot(all(raw_ihme$Unit=='Number'), all(raw_ihme$Measure=='Incidence'),
          all(raw_ihme$Cause=='HIV/AIDS'), all(raw_ihme$Age=='All ages'))
ihme_bounds <- raw_ihme |>
 transmute(country=Location, year=as.integer(Year),
           ihme_value=`Both genders Value`,
           ihme_lower=`Both genders Lower Bound`,
           ihme_upper=`Both genders Upper Bound`)
stopifnot(nrow(ihme_bounds |> count(country,year) |> filter(n>1))==0)
stopifnot(all(ihme_bounds$ihme_lower <= ihme_bounds$ihme_value,na.rm=TRUE),
          all(ihme_bounds$ihme_value <= ihme_bounds$ihme_upper,na.rm=TRUE))
write_csv(ihme_bounds, 'data/ihme_incidence_with_bounds.csv')
write_csv(ihme_bounds |> transmute(country,year,value=ihme_value),
          'data/ihme_incidence.csv')
message('Prepared both sources. Review source-quality outputs after running source_sensitivity.R')

maternal_raw <- read_csv(
  "data/art-coverage-for-pregnant-women.csv",
  show_col_types = FALSE
)

maternal_art <- maternal_raw |>
  filter(Entity %in% countries) |>
  transmute(
    country = Entity,
    year = as.integer(Year),
    value = as.numeric(
      `Antiretroviral therapy coverage for PMTCT (% of pregnant women living with HIV)`
    )
  )
write_csv(maternal_art, "data/maternal_art.csv")
maternal_art |>
  group_by(country) |>
  summarise(
    first_year = min(year),
    last_year = max(year),
    observations = n(),
    missing_values = sum(is.na(value)),
    .groups = "drop"
  )

pediatric_raw <- read_csv(
  "data/share-of-children-under-fifteen-years-old-with-hiv.csv",
  show_col_types = FALSE
)
names(pediatric_raw)
glimpse(pediatric_raw)

pediatric_infections <- pediatric_raw |>
  filter(Entity %in% countries) |>
  transmute(
    country = Entity,
    year = as.integer(Year),
    value = as.numeric(`Best estimate`),
    lower = as.numeric(`Low estimate`),
    upper = as.numeric(`High estimate`)
  )
write_csv(pediatric_infections, "data/pediatric_infections.csv")
pediatric_infections |>
  group_by(country) |>
  summarise(
    first_year = min(year),
    last_year = max(year),
    observations = n(),
    missing_values = sum(is.na(value)),
    .groups = "drop"
  )

inner_join(
  maternal_art,
  pediatric_infections,
  by = c("country", "year"),
  suffix = c("_art", "_pediatric")
) |>
  group_by(country) |>
  summarise(
    paired_years = n(),
    complete_pairs = sum(
      !is.na(value_art) & !is.na(value_pediatric)
    ),
    .groups = "drop"
  )
