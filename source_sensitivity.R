# SOURCE SENSITIVITY AND UNCERTAINTY: matched years 1990–2016
# Run after prepare_source_data.R; independent of maternal ART input files.
library(tidyverse)
dir.create('outputs',showWarnings=FALSE)
dir.create('figures',showWarnings=FALSE)
countries <- c('Kenya','South Africa','Uganda')
unaids_b <- read_csv('data/unaids_incidence_with_bounds.csv',show_col_types=FALSE)
ihme_b <- read_csv('data/ihme_incidence_with_bounds.csv',show_col_types=FALSE)
stopifnot(nrow(unaids_b |> count(country,year) |> filter(n>1))==0,
          nrow(ihme_b |> count(country,year) |> filter(n>1))==0)

# Full grid makes missing country-years visible; no imputation.
expected <- expand_grid(country=countries,year=1990:2016)
paired <- expected |>
 left_join(unaids_b,by=c('country','year')) |>
 left_join(ihme_b,by=c('country','year')) |>
 mutate(complete_point=!is.na(unaids_value) & !is.na(ihme_value),
        complete_bounds=complete_point & !is.na(unaids_lower) & !is.na(unaids_upper) &
                        !is.na(ihme_lower) & !is.na(ihme_upper),
        reason=case_when(is.na(unaids_value) & is.na(ihme_value) ~ 'Both missing',
                         is.na(unaids_value) ~ 'UNAIDS missing',
                         is.na(ihme_value) ~ 'IHME missing',
                         !complete_bounds ~ 'Bounds missing',
                         TRUE ~ 'Complete'),
        intervals_overlap=case_when(!complete_bounds ~ NA,
          TRUE ~ pmax(unaids_lower,ihme_lower) <= pmin(unaids_upper,ihme_upper)),
        unaids_inside_ihme=case_when(!complete_bounds ~ NA,
          TRUE ~ unaids_value >= ihme_lower & unaids_value <= ihme_upper),
        ihme_inside_unaids=case_when(!complete_bounds ~ NA,
          TRUE ~ ihme_value >= unaids_lower & ihme_value <= unaids_upper),
        # Relative interval width is a descriptive indicator of precision.
        unaids_width_pct=if_else(complete_bounds & unaids_value>0,
          100*(unaids_upper-unaids_lower)/unaids_value,NA_real_),
        ihme_width_pct=if_else(complete_bounds & ihme_value>0,
          100*(ihme_upper-ihme_lower)/ihme_value,NA_real_))
write_csv(paired,'outputs/source_sensitivity_paired.csv')
quality <- paired |> group_by(country) |>
 summarise(expected_years=n(),paired_point_years=sum(complete_point),
           paired_with_bounds=sum(complete_bounds),
           missing_point_years=sum(!complete_point),
           .groups='drop')
write_csv(quality,'outputs/source_sensitivity_quality.csv')
exclusions <- paired |> count(country,reason,name='years')
write_csv(exclusions,'outputs/source_sensitivity_exclusions.csv')

#Source-specific calculations and graphics.
long <- bind_rows(
 paired |> transmute(country,year,source='UNAIDS',value=unaids_value,
                      lower=unaids_lower,upper=unaids_upper),
 paired |> transmute(country,year,source='IHME',value=ihme_value,
                      lower=ihme_lower,upper=ihme_upper)) |>
 filter(!is.na(value))
# Fixed-calendar-year comparisons:
# Unlike peak-to-endpoint change, these can be positive or negative.

fixed_window_change <- long |>
  filter(year %in% c(2000, 2010, 2016)) |>
  select(country, source, year, value) |>
  pivot_wider(
    names_from = year,
    values_from = value,
    names_prefix = "y"
  ) |>
  mutate(
    change_2000_2016 = if_else(
      !is.na(y2000) & y2000 > 0 & !is.na(y2016),
      100 * (y2016 / y2000 - 1),
      NA_real_
    ),
    change_2010_2016 = if_else(
      !is.na(y2010) & y2010 > 0 & !is.na(y2016),
      100 * (y2016 / y2010 - 1),
      NA_real_
    )
  )

write_csv(
  fixed_window_change,
  "outputs/source_fixed_window_change.csv"
)

print(fixed_window_change)

# Stage 1: peak within 1990–2016; ties resolve to earliest year.
# Peak-to-2016 change and mean annual change = endpoint difference / elapsed years.
# No post-peak decline is computable if the peak is in 2016.
progress <- long |>
 group_by(country,source) |>
 arrange(year,.by_group=TRUE) |>
 summarise(n_years=n(),
           peak_year=year[which.max(value)],
           peak_value=max(value),
           endpoint_value=if (2016 %in% year) value[match(2016,year)] else NA_real_,
           .groups='drop') |>
 mutate(elapsed_years=2016-peak_year,
        peak_to_2016_pct=if_else(elapsed_years>0 & peak_value>0,
                                 100*(endpoint_value-peak_value)/peak_value,NA_real_),
        annual_change_count=if_else(elapsed_years>0,
                         (endpoint_value-peak_value)/elapsed_years,NA_real_))
write_csv(progress,'outputs/source_sensitivity_progress.csv')

# Stage 2: uncertainty in annual estimates, not a formal CI for the decline.
uncertainty <- paired |> group_by(country) |>
 summarise(n_interval_pairs=sum(complete_bounds),
           n_overlap=sum(intervals_overlap,na.rm=TRUE),
           pct_overlap=if_else(n_interval_pairs>0,100*n_overlap/n_interval_pairs,NA_real_),
           n_unaids_inside_ihme=sum(unaids_inside_ihme,na.rm=TRUE),
           n_ihme_inside_unaids=sum(ihme_inside_unaids,na.rm=TRUE),
           median_unaids_width_pct=median(unaids_width_pct,na.rm=TRUE),
           median_ihme_width_pct=median(ihme_width_pct,na.rm=TRUE),
           .groups='drop')
write_csv(uncertainty,'outputs/source_sensitivity_uncertainty.csv')

# Stage 3: compare point-estimate conclusions, including rankings.
comparison <- progress |>
 select(country,source,peak_year,peak_to_2016_pct,annual_change_count) |>
 pivot_wider(names_from=source,values_from=c(peak_year,peak_to_2016_pct,annual_change_count)) |>
 mutate(peak_year_difference=peak_year_UNAIDS-peak_year_IHME,
        pct_change_difference=peak_to_2016_pct_UNAIDS-peak_to_2016_pct_IHME,
        same_direction=case_when(is.na(peak_to_2016_pct_UNAIDS) |
                                 is.na(peak_to_2016_pct_IHME) ~ NA,
                                 TRUE ~ sign(peak_to_2016_pct_UNAIDS)==sign(peak_to_2016_pct_IHME)))
write_csv(comparison,'outputs/source_sensitivity_conclusions.csv')
ranking <- progress |> group_by(source) |>
 mutate(rank_by_decline=min_rank(peak_to_2016_pct)) |> ungroup() |>
 select(country,source,rank_by_decline) |>
 pivot_wider(names_from=source,values_from=rank_by_decline) |>
 mutate(same_rank=UNAIDS==IHME)
write_csv(ranking,'outputs/source_sensitivity_rankings.csv')

# Endpoint-bound stress test. Bounds at peak year and 2016
# are plugged into a fixed-peak percent-change formula. This is NOT a 95% CI
# for decline and does not re-estimate the peak under alternative trajectories.
endpoint_bounds <- long |>
 inner_join(progress |> select(country,source,peak_year),by=c('country','source')) |>
 filter(year==peak_year | year==2016) |>
 mutate(position=if_else(year==peak_year,'peak','end')) |>
 select(country,source,peak_year,position,lower,upper) |>
 pivot_wider(names_from=position,values_from=c(lower,upper)) |>
 mutate(stress_smallest_pct=if_else(lower_peak>0 & !is.na(lower_end) & !is.na(upper_peak) & peak_year<2016,
                       100*(lower_end/upper_peak-1),NA_real_),
        stress_largest_pct=if_else(lower_peak>0 & !is.na(upper_end) & !is.na(lower_peak) & peak_year<2016,
                       100*(upper_end/lower_peak-1),NA_real_),
        stress_sign_stable=case_when(is.na(stress_smallest_pct) |
                             is.na(stress_largest_pct) ~ NA,
                             stress_largest_pct<0 ~ 'Decline across endpoints',
                             stress_smallest_pct>0 ~ 'Increase across endpoints',
                             TRUE ~ 'Direction depends on endpoints'))
write_csv(endpoint_bounds,'outputs/source_sensitivity_stress_test.csv')

# Figure 1: source-specific trajectories, with uncertainty ribbons.
p_trajectories <- ggplot(long,aes(year,value,color=source,fill=source)) +
 geom_ribbon(aes(ymin=lower,ymax=upper),alpha=.13,color=NA,na.rm=TRUE) +
 geom_line(linewidth=.8) +
 geom_vline(data=progress,aes(xintercept=peak_year,color=source),
            linetype='dotted',alpha=.7,show.legend=FALSE) +
 facet_wrap(~country,scales='free_y') +
 labs(title='Estimated annual new HIV infections, 1990–2016',
      subtitle='Dotted lines mark source-specific observed peak years',
      x='Year',y='Estimated new infections (count)',
      caption='Shading: source-reported uncertainty intervals; not uncertainty for trends') +
 theme_minimal()
ggsave('figures/source_trajectories.png',p_trajectories,width=10,height=5.5,dpi=160)

# Figure 2: compare uncertainty intervals for a small, labeled year sample.
selected_years <- c(1990,2000,2010,2016)
p_intervals <- long |> filter(year %in% selected_years) |>
 ggplot(aes(x=source,y=value,ymin=lower,ymax=upper,color=source)) +
 geom_pointrange(position=position_dodge(width=.35)) +
 facet_grid(country~year,scales='free_y') +
 labs(title='Annual incidence estimates and uncertainty intervals',
      subtitle='Selected years; vertical intervals are reported by each source',
      x=NULL,y='Estimated new infections (count)') +
 theme_minimal()
ggsave('figures/source_intervals.png',p_intervals,width=10,height=7,dpi=160)

# Figure 3: dumbbell-style source sensitivity of peak-to-2016 change.
p_sensitivity <- progress |>
 filter(!is.na(peak_to_2016_pct)) |>
 ggplot(aes(peak_to_2016_pct,country,color=source)) +
 geom_segment(data=comparison,aes(x=peak_to_2016_pct_UNAIDS,
                               xend=peak_to_2016_pct_IHME,y=country,yend=country),
           inherit.aes=FALSE,color='gray60',linewidth=.6) +
 geom_point(size=3) +
 labs(title='Does the data source change estimated post-peak progress?',
      subtitle='Percent change from each source’s observed peak to 2016',
      x='Peak-to-2016 change (%)',y=NULL,
      caption='Peaks may occur in different years; this is a descriptive sensitivity check') +
 theme_minimal()
ggsave('figures/source_sensitivity.png',p_sensitivity,width=9,height=4.5,dpi=160)

print(quality)
print(comparison)
message('Source sensitivity analysis complete. Review outputs/ and figures/.')
