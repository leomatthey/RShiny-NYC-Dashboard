# ui.R — NYC Traffic Accidents 2020 Dashboard
# ============================================================================
# Constants (colors, orders, plotly defaults) are defined in global.R.

# UI Definition ====
ui <- dashboardPage(
  skin = "black",

  ## Header ----
  dashboardHeader(
    title = tagList(
      tags$span("NYC Accidents"),
      tags$b(" 2020")
    ),
    titleWidth = 250
  ),

  ## Sidebar ----
  dashboardSidebar(
    width = 250,

    # Navigation menu (kept separate from filters for proper tab routing)
    sidebarMenu(
      id = "tabs",
      menuItem("Overview",          tabName = "overview",  icon = icon("chart-bar"), selected = TRUE),
      menuItem("Interactive Map",   tabName = "map",       icon = icon("map-marked-alt")),
      menuItem("Time Analysis",     tabName = "time",      icon = icon("clock")),
      menuItem("Causes & Vehicles", tabName = "causes",    icon = icon("exclamation-triangle")),
      menuItem("Route Risk",        tabName = "predictor", icon = icon("robot"))
    ),

    # Filter controls (outside sidebarMenu, hidden on Route Risk tab)
    tags$div(id = "sidebar-filters",
      tags$div(class = "sidebar-section-sep"),
      tags$div(class = "sidebar-header", "Filters"),

      # Hour range
      sliderInput("hour_range", "Hour of Day",
                  min = 0, max = 23, value = c(0, 23), step = 1),

      # Borough
      pickerInput("borough", "Borough",
                  choices  = BOROUGH_CHOICES,
                  selected = BOROUGH_CHOICES,
                  multiple = TRUE,
                  options  = pickerOptions(
                    actionsBox     = TRUE,
                    liveSearch     = FALSE,
                    selectedTextFormat = "count > 2",
                    countSelectedText  = "{0} boroughs"
                  )),

      # Severity
      pickerInput("severity", "Severity",
                  choices  = SEVERITY_CHOICES,
                  selected = SEVERITY_CHOICES,
                  multiple = TRUE,
                  options  = pickerOptions(
                    actionsBox     = TRUE,
                    selectedTextFormat = "count > 2",
                    countSelectedText  = "{0} levels"
                  )),

      # Month range
      sliderInput("month_range", "Month",
                  min = 1, max = MAX_MONTH, value = c(1, MAX_MONTH), step = 1),

      # Commuter type
      pickerInput("commuter_type", "Commuter Type",
                  choices  = c("All", "Pedestrian", "Cyclist", "Motorist"),
                  selected = "All",
                  multiple = FALSE),

      # Reset button (width controlled via CSS to match .form-group padding)
      actionButton("reset_filters", "Reset Filters",
                   icon  = icon("undo")),

      # Crash count badge (updated via JS)
      tags$div(id = "crash-count-badge",
        tags$div(class = "badge-label", "Matching Crashes"),
      tags$div(class = "badge-value", "---")
      )
    ) # end sidebar-filters
  ),

  ## Body ----
  dashboardBody(
    # External CSS/JS
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
      tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
      tags$link(rel = "stylesheet",
                href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"),
      tags$style("body { font-family: 'Inter', system-ui, sans-serif; }")
    ),
    useShinyjs(),
    tags$script(src = "custom.js"),

    # Welcome splash overlay
    tags$div(id = "splash-overlay", class = "splash-overlay",
      tags$div(class = "splash-card",
        tags$div(class = "splash-header",
          tags$div(class = "splash-badge", "NYC"),
          tags$h1(class = "splash-title", "Traffic Accidents 2020"),
          tags$p(class = "splash-subtitle", "Interactive Data Analytics Dashboard")
        ),
        tags$div(class = "splash-divider"),
        tags$div(class = "splash-body",
          tags$div(class = "splash-stats",
            tags$div(class = "splash-stat",
              tags$div(class = "splash-stat-value", "74,881"),
              tags$div(class = "splash-stat-label", "Crashes Analysed")
            ),
            tags$div(class = "splash-stat",
              tags$div(class = "splash-stat-value", "5"),
              tags$div(class = "splash-stat-label", "Boroughs Covered")
            ),
            tags$div(class = "splash-stat",
              tags$div(class = "splash-stat-value", "5"),
              tags$div(class = "splash-stat-label", "Interactive Dashboards")
            )
          ),
          tags$p(class = "splash-description",
            "Explore New York City's traffic accident landscape through interactive visualisations.",
            "Dive into borough comparisons, temporal patterns, contributing factors, and plan safer",
            "routes with our spatial risk analysis tool."
          ),
          tags$div(class = "splash-features",
            tags$div(class = "splash-feature",
              tags$span(class = "splash-feature-icon", icon("chart-bar")),
              tags$span("City-wide overview with key metrics and borough breakdowns")
            ),
            tags$div(class = "splash-feature",
              tags$span(class = "splash-feature-icon", icon("map-marked-alt")),
              tags$span("Interactive heatmap with street-level crash data")
            ),
            tags$div(class = "splash-feature",
              tags$span(class = "splash-feature-icon", icon("clock")),
              tags$span("Temporal analysis revealing when and where crashes peak")
            ),
            tags$div(class = "splash-feature",
              tags$span(class = "splash-feature-icon", icon("exclamation-triangle")),
              tags$span("Deep dive into crash causes and vehicle type patterns")
            ),
            tags$div(class = "splash-feature",
              tags$span(class = "splash-feature-icon", icon("route")),
              tags$span("Route risk analysis with danger zone detection")
            )
          )
        ),
        tags$div(class = "splash-footer",
          actionButton("dismiss_splash", "Explore the Dashboard",
                       class = "splash-btn", icon = icon("arrow-right")),
          tags$p(class = "splash-credit",
            "Data Analytics with R \u2014 ESADE MiBA \u2014 Term 2, 2025")
        )
      )
    ),

    tabItems(

      # ── Tab 1: Overview ──────────────────────────────────────────────────
      tabItem(tabName = "overview",
        tags$h2(class = "page-title", "Overview"),

        tags$h3(class = "section-header", "Key Metrics"),
        fluidRow(
          valueBoxOutput("kpi_crashes",     width = 3),
          valueBoxOutput("kpi_injured",     width = 3),
          valueBoxOutput("kpi_fatalities",  width = 3),
          valueBoxOutput("kpi_injury_rate", width = 3)
        ),

        fluidRow(
          column(width = 7,
            tags$h3(class = "section-header", "How Do Boroughs Compare?"),
            box(title = "Borough Comparison", width = NULL, solidHeader = FALSE,
                plotlyOutput("overview_borough", height = "300px"))
          ),
          column(width = 5,
            tags$h3(class = "section-header", "Who Gets Injured?"),
            box(title = "Injured by Victim Type", width = NULL, solidHeader = FALSE,
                plotlyOutput("overview_victim_donut", height = "300px"))
          )
        ),

        fluidRow(
          column(width = 6,
            tags$h3(class = "section-header", "When Do Most Crashes Occur?"),
            box(title = "Hourly Crash Distribution", width = NULL, solidHeader = FALSE,
                plotlyOutput("overview_hourly", height = "280px"))
          ),
          column(width = 6,
            tags$h3(class = "section-header", "How Severe Are They by Borough?"),
            box(title = "Severity by Borough", width = NULL, solidHeader = FALSE,
                plotlyOutput("overview_severity_borough", height = "280px"))
          )
        ),

        tags$h3(class = "section-header", "How Vulnerable Are Pedestrians & Cyclists?"),
        fluidRow(
          box(title = "Pedestrian & Cyclist Vulnerability by Borough", width = 12,
              solidHeader = FALSE,
              plotlyOutput("overview_borough_vulnerability", height = "300px"))
        )
      ),

      # ── Tab 2: Interactive Map ───────────────────────────────────────────
      tabItem(tabName = "map",
        tags$h2(class = "page-title", "Interactive Map"),

        tags$h3(class = "section-header", "Crash Map"),
        fluidRow(
          column(width = 10,
            box(title = NULL, width = NULL, solidHeader = FALSE,
              leafletOutput("crash_map", height = "650px")
            )
          ),
          column(width = 2,
            tags$div(class = "section-divider", "Map Controls"),
            radioGroupButtons("map_mode", label = NULL,
                              choices  = c("Heatmap", "Markers"),
                              selected = "Heatmap",
                              justified = TRUE, size = "sm",
                              status = "primary"),
            tags$br(),
            tags$div(class = "section-divider", "Statistics"),
            uiOutput("map_stats")
          )
        ),

        tags$h3(class = "section-header", "Where Are the Most Dangerous Streets?"),
        fluidRow(
          box(title = "Most Dangerous Streets", width = 12, solidHeader = FALSE,
              DTOutput("dangerous_streets"))
        )
      ),

      # ── Tab 3: Time Analysis ─────────────────────────────────────────────
      tabItem(tabName = "time",
        tags$h2(class = "page-title", "Time Analysis"),

        tags$h3(class = "section-header", "When Do Accidents Happen?"),
        fluidRow(
          box(title = "Crash Timing Heatmap", width = 12, solidHeader = FALSE,
              plotlyOutput("time_heatmap", height = "280px"))
        ),

        fluidRow(
          column(width = 6,
            tags$h3(class = "section-header", "Which Days Are Most Dangerous?"),
            box(title = "Day-of-Week Pattern", width = NULL, solidHeader = FALSE,
                plotlyOutput("time_dow", height = "280px"))
          ),
          column(width = 6,
            tags$h3(class = "section-header", "Who Is Affected by Time of Day?"),
            box(title = "Time of Day by Victim Type", width = NULL, solidHeader = FALSE,
                plotlyOutput("time_victim", height = "280px"))
          )
        ),

        fluidRow(
          column(width = 6,
            tags$h3(class = "section-header", "How Do Crashes Change by Month?"),
            box(title = "Monthly Crash Volume", width = NULL, solidHeader = FALSE,
                plotlyOutput("time_monthly", height = "280px"))
          ),
          column(width = 6,
            tags$h3(class = "section-header", "How Do Crashes Vary by Borough and Hour?"),
            box(title = "Hour x Borough Heatmap", width = NULL, solidHeader = FALSE,
                plotlyOutput("time_borough_heatmap", height = "280px"))
          )
        )
      ),

      # ── Tab 4: Causes & Vehicles ─────────────────────────────────────────
      tabItem(tabName = "causes",
        tags$h2(class = "page-title", "Causes & Vehicles"),

        tags$h3(class = "section-header", "What Are the Top Contributing Factors?"),
        fluidRow(
          box(title = "Top Contributing Factors", width = 12, solidHeader = FALSE,
              plotlyOutput("causes_top_factors", height = "340px"))
        ),

        fluidRow(
          column(width = 6,
            tags$h3(class = "section-header", "How Severe Are Different Factors?"),
            box(title = "Factor Severity Profile", width = NULL, solidHeader = FALSE,
                plotlyOutput("causes_factor_severity", height = "300px"))
          ),
          column(width = 6,
            tags$h3(class = "section-header", "How Do Factor Categories Trend Over Time?"),
            box(title = "Factor Category Trends", width = NULL, solidHeader = FALSE,
                plotlyOutput("causes_factor_time", height = "300px"))
          )
        ),

        fluidRow(
          column(width = 6,
            tags$h3(class = "section-header", "How Severe Are Crashes by Vehicle Type?"),
            box(title = "Vehicle Type x Severity", width = NULL, solidHeader = FALSE,
                plotlyOutput("causes_vehicle_severity", height = "300px"))
          ),
          column(width = 6,
            tags$h3(class = "section-header", "What Causes Crashes for Each Vehicle?"),
            box(title = "Factor Composition by Vehicle", width = NULL, solidHeader = FALSE,
                plotlyOutput("causes_factor_vehicle", height = "300px"))
          )
        )
      ),

      # ── Tab 5: Route Risk Predictor ──────────────────────────────────────
      tabItem(tabName = "predictor",

        # Info box
        fluidRow(
          box(width = 12, solidHeader = FALSE,
            tags$div(class = "route-info-box",
              tags$h4(class = "page-title", "Route Risk Analysis"),
              tags$p("Enter an origin and destination to analyse historical crash data along your route.",
                     "The map highlights danger zones in yellow to red. Below, you\u2019ll find key statistics,",
                     "the most dangerous spots, and breakdowns by time, vehicle type, and contributing factors.")
            )
          )
        ),

        # Route configuration (full width, horizontal)
        tags$h3(class = "section-header", style = "margin-top:0;", "Route Configuration"),
        fluidRow(
          box(title = NULL, width = 12, solidHeader = FALSE,
            fluidRow(
              column(width = 4,
                tags$label(class = "control-label", "From"),
                selectizeInput("route_origin", label = NULL, choices = NULL,
                  options = list(
                    placeholder  = "Type to search NYC addresses...",
                    create       = FALSE,
                    loadThrottle = 400,
                    render = I('{
                      option: function(item, escape) { return "<div>" + escape(item.label) + "</div>"; },
                      item:   function(item, escape) { return "<div>" + escape(item.label) + "</div>"; }
                    }'),
                    load = I(glue('function(query, callback) {{
                      if (!query) return callback();
                      $.getJSON("https://api.openrouteservice.org/geocode/autocomplete", {{
                        api_key: "{ORS_API_KEY}",
                        text: query,
                        "boundary.rect.min_lon": -74.26,
                        "boundary.rect.max_lon": -73.70,
                        "boundary.rect.min_lat": 40.49,
                        "boundary.rect.max_lat": 40.92,
                        size: 5
                      }}, function(data) {{
                        callback(data.features.map(function(f) {{
                          return {{
                            value: f.geometry.coordinates[1] + "|" + f.geometry.coordinates[0] + "|" + f.properties.label,
                            label: f.properties.label
                          }};
                        }}));
                      }}).fail(function() {{ callback(); }});
                    }}'))
                  )
                )
              ),
              column(width = 4,
                tags$label(class = "control-label", "To"),
                selectizeInput("route_dest", label = NULL, choices = NULL,
                  options = list(
                    placeholder  = "Type to search NYC addresses...",
                    create       = FALSE,
                    loadThrottle = 400,
                    render = I('{
                      option: function(item, escape) { return "<div>" + escape(item.label) + "</div>"; },
                      item:   function(item, escape) { return "<div>" + escape(item.label) + "</div>"; }
                    }'),
                    load = I(glue('function(query, callback) {{
                      if (!query) return callback();
                      $.getJSON("https://api.openrouteservice.org/geocode/autocomplete", {{
                        api_key: "{ORS_API_KEY}",
                        text: query,
                        "boundary.rect.min_lon": -74.26,
                        "boundary.rect.max_lon": -73.70,
                        "boundary.rect.min_lat": 40.49,
                        "boundary.rect.max_lat": 40.92,
                        size: 5
                      }}, function(data) {{
                        callback(data.features.map(function(f) {{
                          return {{
                            value: f.geometry.coordinates[1] + "|" + f.geometry.coordinates[0] + "|" + f.properties.label,
                            label: f.properties.label
                          }};
                        }}));
                      }}).fail(function() {{ callback(); }});
                    }}'))
                  )
                )
              ),
              column(width = 4,
                actionButton("analyse_route_btn", "Analyse Route",
                             icon = icon("route"), class = "route-analyse-btn"),
                checkboxInput("show_crash_dots", "Show crash locations", value = FALSE)
              )
            )
          )
        ),

        # Map (full width)
        tags$h3(class = "section-header", "Route Map"),
        fluidRow(
          box(title = NULL, width = 12, solidHeader = FALSE,
            leafletOutput("route_map", height = "520px")
          )
        ),

        # Analysis panels (revealed after route analysis)
        shinyjs::hidden(
          div(id = "route_results",

            tags$h3(class = "section-header", "Route Overview"),
            uiOutput("route_kpis"),

            tags$h3(class = "section-header", "Top Danger Zones"),
            uiOutput("danger_zone_cards"),

            tags$h3(class = "section-header", "When Do Crashes Happen?"),
            fluidRow(
              column(width = 6,
                box(title = "Crashes by Day of Week", width = NULL, solidHeader = FALSE,
                  plotlyOutput("corridor_dow", height = "280px"))
              ),
              column(width = 6,
                box(title = "Crashes by Hour of Day", width = NULL, solidHeader = FALSE,
                  plotlyOutput("corridor_hourly", height = "280px"))
              )
            ),

            fluidRow(
              column(width = 6,
                tags$h3(class = "section-header", "Which Vehicles Are Involved?"),
                box(title = "Crashes by Vehicle Type", width = NULL, solidHeader = FALSE,
                  plotlyOutput("corridor_mode_risk", height = "340px"))
              ),
              column(width = 6,
                tags$h3(class = "section-header", "What Are the Top Causes?"),
                box(title = "Top Contributing Factors", width = NULL, solidHeader = FALSE,
                  plotlyOutput("corridor_factors", height = "340px"))
              )
            )
          )
        ),


      )
    ) # end tabItems
  ) # end dashboardBody
) # end dashboardPage
