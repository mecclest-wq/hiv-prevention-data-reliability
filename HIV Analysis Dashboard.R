
# Shiny companion dashboard
# Run analysis.R before launching the app.

library(shiny)
library(tidyverse)

# Load analysis outputs
needed <- c(
  "outputs/post_peak.csv",
  "outputs/maternal_lag_data.csv",
  "outputs/source_sensitivity_paired.csv",
  "outputs/source_sensitivity_progress.csv",
  "outputs/source_sensitivity_conclusions.csv",
  "outputs/source_sensitivity_quality.csv"
)

if (!all(file.exists(needed))) {
  stop(
    "Missing outputs: run prepare_source_data.R, ",
    "source_sensitivity.R, and analysis.R first."
  )
}

post_peak <- read_csv(needed[1], show_col_types = FALSE)
maternal <- read_csv(needed[2], show_col_types = FALSE)
paired <- read_csv(needed[3], show_col_types = FALSE)
progress <- read_csv(needed[4], show_col_types = FALSE)
conclusions <- read_csv(needed[5], show_col_types = FALSE)
quality <- read_csv(needed[6], show_col_types = FALSE)

# USER INTERFACE --------------------------------------------------

ui <- fluidPage(
  
  titlePanel("HIV Epidemic Progress and Data Reliability"),
  
  p(
    "Population-level modeled estimates; descriptive analysis, ",
    "not causal inference."
  ),
  
  sidebarLayout(
    
    sidebarPanel(
      
      selectInput(
        "section",
        "Analysis",
        choices = c(
          "Post-peak trajectories",
          "Maternal ART and pediatric HIV",
          "Source sensitivity and uncertainty",
          "Source data quality"
        )
      ),
      
      checkboxGroupInput(
        "countries",
        "Countries",
        choices = c("Kenya", "South Africa", "Uganda"),
        selected = c("Kenya", "South Africa", "Uganda")
      ),
      
      conditionalPanel(
        "input.section == 'Maternal ART and pediatric HIV'",
        
        selectInput(
          "lag",
          "Years between ART coverage and pediatric infections",
          choices = 0:3,
          selected = 2,
          ),
        helpText(
            "For example, selecting 2 compares maternal ART coverage ",
            "in 2000 with estimated pediatric HIV infections in 2002. ",
            "These comparisons describe associations, not causal effects."
          )
      ),
      
      conditionalPanel(
        "input.section == 'Source sensitivity and uncertainty'",
        
        selectInput(
          "view",
          "Source view",
          choices = c(
            "Trajectories",
            "Uncertainty intervals",
            "Sensitivity of decline"
          )
        ),
        
        conditionalPanel(
          "input.view == 'Uncertainty intervals'",
          
          selectInput(
            "year",
            "Uncertainty interval year",
            choices = 1990:2016,
            selected = 2016
          )
        )
      )
    ),
    
    mainPanel(
      
      # Display graphs for analyses other than data quality
      conditionalPanel(
        "input.section != 'Source data quality'",
        
        plotOutput(
          "chart",
          height = "480px"
        )
      ),
      
      # Replace the data-quality bar chart with a text summary
      conditionalPanel(
        "input.section == 'Source data quality'",
        
        h4("Data Completeness: UNAIDS vs. IHME"),
        
        textOutput("quality_message")
      ),
      
      h4("Summary"),
      
      tableOutput("summary"),
      
      conditionalPanel(
        "input.section == 'Source sensitivity and uncertainty' || input.section == 'Source data quality'",
        
        p(
          "Source comparison: 1990–2016, both sexes, all ages, ",
          "annual infection counts. Annual uncertainty intervals ",
          "do not provide a confidence interval for percentage decline."
        )
      )
    )
  )
)

# SERVER ----------------------------------------------------------

server <- function(input, output, session) {
  
  # MAIN VISUALIZATIONS -------------------------------------------
  
  output$chart <- renderPlot({
    
    req(length(input$countries) > 0)
    
    if (input$section == "Post-peak trajectories") {
      
      x <- post_peak |>
        filter(country %in% input$countries)
      
      ggplot(
        x,
        aes(
          x = years_since_peak,
          y = percent_of_peak,
          color = country
        )
      ) +
        geom_line(linewidth = 1, na.rm = TRUE) +
        labs(
          x = "Years since peak",
          y = "% of peak",
          color = "Country"
        ) +
        theme_minimal()
      
    } else if (input$section == "Maternal ART and pediatric HIV") {
      
      x <- maternal |>
        filter(
          country %in% input$countries,
          lag_years == as.integer(input$lag),
          included
        )
      
      validate(
        need(
          nrow(x) > 0,
          "No complete observations for this lag."
        )
      )
      
      ggplot(
        x,
        aes(
          x = art_percent,
          y = child_infections,
          color = country
        )
      ) +
        geom_point(size = 2, alpha = 0.8) +
        labs(
          x = "Maternal ART coverage (%)",
          y = "Pediatric infections (count)",
          color = "Country"
        ) +
        theme_minimal()
      
    } else if (input$section == "Source data quality") {
      
      # No chart is needed for this section.
      # The completeness message and table appear instead.
      return(NULL)
      
    } else if (input$view == "Sensitivity of decline") {
      
      x <- progress |>
        filter(
          country %in% input$countries,
          !is.na(peak_to_2016_pct)
        )
      
      validate(
        need(nrow(x) > 0, "No source sensitivity data available.")
      )
      
      ggplot(
        x,
        aes(
          x = peak_to_2016_pct,
          y = country,
          color = source
        )
      ) +
        geom_point(size = 3) +
        labs(
          x = "Change from source-specific peak to 2016 (%)",
          y = NULL,
          color = "Source"
        ) +
        theme_minimal()
      
    } else {
      
      # Convert paired UNAIDS/IHME data to long format
      x <- paired |>
        filter(country %in% input$countries)
      
      x <- bind_rows(
        
        x |>
          transmute(
            country,
            year,
            source = "UNAIDS",
            value = unaids_value,
            lower = unaids_lower,
            upper = unaids_upper
          ),
        
        x |>
          transmute(
            country,
            year,
            source = "IHME",
            value = ihme_value,
            lower = ihme_lower,
            upper = ihme_upper
          )
      )
      
      if (input$view == "Uncertainty intervals") {
        
        x <- x |>
          filter(year == as.integer(input$year))
        
        validate(
          need(nrow(x) > 0, "No estimates available for this year.")
        )
        
        ggplot(
          x,
          aes(
            x = source,
            y = value,
            ymin = lower,
            ymax = upper,
            color = source
          )
        ) +
          geom_pointrange() +
          facet_wrap(~country, scales = "free_y") +
          labs(
            x = NULL,
            y = "Annual new infections (count)",
            color = "Source"
          ) +
          theme_minimal()
        
      } else {
        
        validate(
          need(nrow(x) > 0, "No trajectory data available.")
        )
        
        ggplot(
          x,
          aes(
            x = year,
            y = value,
            color = source,
            fill = source
          )
        ) +
          geom_ribbon(
            aes(
              ymin = lower,
              ymax = upper
            ),
            alpha = 0.12,
            color = NA
          ) +
          geom_line(linewidth = 0.8) +
          facet_wrap(~country, scales = "free_y") +
          labs(
            x = "Year",
            y = "Annual new infections (count)",
            color = "Source",
            fill = "Source"
          ) +
          theme_minimal()
      }
    }
  })
  
  # DATA QUALITY MESSAGE ------------------------------------------
  
  
  output$quality_message <- renderText({
    
    req(length(input$countries) > 0)
    
    selected <- quality |>
      filter(country %in% input$countries)
    
    validate(
      need(nrow(selected) > 0, "No data-quality records available.")
    )
    
    total_expected <- sum(selected$expected_years, na.rm = TRUE)
    total_complete <- sum(selected$paired_with_bounds, na.rm = TRUE)
    
    validate(
      need(total_expected > 0, "No expected observations available.")
    )
    
    completeness_pct <- 100 * total_complete / total_expected
    
    paste0(
      round(completeness_pct, 1),
      "% of expected country-year observations have HIV infection ",
      "estimates and uncertainty bounds available from both UNAIDS ",
      "and IHME for the selected countries."
    )
  })
  
  
  # SUMMARY TABLES ------------------------------------------------
  
  output$summary <- renderTable({
    
    req(length(input$countries) > 0)
    
    if (input$section == "Source data quality") {
      
      quality |>
        filter(country %in% input$countries)
      
    } else if (input$section == "Source sensitivity and uncertainty") {
      
      conclusions |>
        filter(country %in% input$countries)
      
    } else if (input$section == "Maternal ART and pediatric HIV") {
      
      maternal |>
        filter(
          country %in% input$countries,
          lag_years == as.integer(input$lag)
        ) |>
        group_by(country) |>
        summarise(
          available = sum(included, na.rm = TRUE),
          total = n(),
          .groups = "drop"
        )
      
    } else {
      
      post_peak |>
        filter(country %in% input$countries) |>
        group_by(country) |>
        summarise(
          n_years = sum(!is.na(percent_of_peak)),
          .groups = "drop"
        )
    }
  })
}

# LAUNCH APP ------------------------------------------------------

shinyApp(ui = ui, server = server)

