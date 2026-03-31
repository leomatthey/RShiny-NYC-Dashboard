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

    # Filter controls (outside sidebarMenu)
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

    tabItems(

      # ── Tab 1: Overview ──────────────────────────────────────────────────
      tabItem(tabName = "overview",
        # Row 1: KPI boxes
        fluidRow(
          valueBoxOutput("kpi_crashes",     width = 3),
          valueBoxOutput("kpi_injured",     width = 3),
          valueBoxOutput("kpi_fatalities",  width = 3),
          valueBoxOutput("kpi_injury_rate", width = 3)
        ),
        # Row 2: Borough comparison + Victim donut
        fluidRow(
          box(title = "Borough Comparison", width = 7, solidHeader = FALSE,
              plotlyOutput("overview_borough", height = "300px")),
          box(title = "Injured by Victim Type", width = 5, solidHeader = FALSE,
              plotlyOutput("overview_victim_donut", height = "300px"))
        ),
        # Row 3: Hourly distribution + Severity by borough
        fluidRow(
          box(title = "Hourly Crash Distribution", width = 6, solidHeader = FALSE,
              plotlyOutput("overview_hourly", height = "280px")),
          box(title = "Severity by Borough", width = 6, solidHeader = FALSE,
              plotlyOutput("overview_severity_borough", height = "280px"))
        ),
        # Row 4: Pedestrian & Cyclist Vulnerability
        fluidRow(
          box(title = "Pedestrian & Cyclist Vulnerability by Borough", width = 12,
              solidHeader = FALSE,
              plotlyOutput("overview_borough_vulnerability", height = "300px"))
        )
      ),

      # ── Tab 2: Interactive Map ───────────────────────────────────────────
      tabItem(tabName = "map",
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
        fluidRow(
          box(title = "Most Dangerous Streets", width = 12, solidHeader = FALSE,
              DTOutput("dangerous_streets"))
        )
      ),

      # ── Tab 3: Time Analysis ─────────────────────────────────────────────
      tabItem(tabName = "time",
        # Row 1: Full-width heatmap
        fluidRow(
          box(title = "When Do Accidents Happen? \u2014 Hour x Day of Week",
              width = 12, solidHeader = FALSE,
              plotlyOutput("time_heatmap", height = "280px"))
        ),
        # Row 2: Day-of-week + Victim by time
        fluidRow(
          box(title = "Day-of-Week Pattern", width = 6, solidHeader = FALSE,
              plotlyOutput("time_dow", height = "280px")),
          box(title = "Time of Day by Victim Type", width = 6, solidHeader = FALSE,
              plotlyOutput("time_victim", height = "280px"))
        ),
        # Row 3: Monthly + Borough heatmap
        fluidRow(
          box(title = "Monthly Crash Volume", width = 6, solidHeader = FALSE,
              plotlyOutput("time_monthly", height = "280px")),
          box(title = "Hour x Borough Heatmap", width = 6, solidHeader = FALSE,
              plotlyOutput("time_borough_heatmap", height = "280px"))
        )
      ),

      # ── Tab 4: Causes & Vehicles ─────────────────────────────────────────
      tabItem(tabName = "causes",
        # Row 1: Full-width top factors
        fluidRow(
          box(title = "Top Contributing Factors", width = 12, solidHeader = FALSE,
              plotlyOutput("causes_top_factors", height = "340px"))
        ),
        # Row 2: Factor severity profile + Factor category trends
        fluidRow(
          box(title = "Factor Severity Profile", width = 6, solidHeader = FALSE,
              plotlyOutput("causes_factor_severity", height = "300px")),
          box(title = "Factor Category Trends", width = 6, solidHeader = FALSE,
              plotlyOutput("causes_factor_time", height = "300px"))
        ),
        # Row 3: Vehicle x severity + Factor by vehicle
        fluidRow(
          box(title = "Vehicle Type x Severity", width = 6, solidHeader = FALSE,
              plotlyOutput("causes_vehicle_severity", height = "300px")),
          box(title = "Factor Composition by Vehicle", width = 6, solidHeader = FALSE,
              plotlyOutput("causes_factor_vehicle", height = "300px"))
        )
      ),

      # ── Tab 5: Route Risk Predictor ──────────────────────────────────────
      tabItem(tabName = "predictor",
        # Row 1: Route inputs + Map
        fluidRow(
          column(width = 4,
            box(title = "Route Configuration", width = NULL, solidHeader = FALSE,
              selectizeInput("route_origin", "From", choices = NULL,
                options = list(
                  placeholder = "Type to search NYC addresses...",
                  create = FALSE,
                  render = I('{ option: function(item, escape) { return "<div>" + escape(item.label) + "</div>"; }, item: function(item, escape) { return "<div>" + escape(item.label) + "</div>"; } }'),
                  load = I('function(query, callback) {
                    if (!query || query.length < 3) return callback();
                    $.getJSON("https://nominatim.openstreetmap.org/search", {
                      q: query + " New York City", format: "json", limit: 5
                    }, function(data) {
                      callback(data.map(function(d) {
                        return { value: d.lat + "|" + d.lon + "|" + d.display_name, label: d.display_name };
                      }));
                    }).fail(function() { callback(); });
                  }')
                )
              ),
              selectizeInput("route_dest", "To", choices = NULL,
                options = list(
                  placeholder = "Type to search NYC addresses...",
                  create = FALSE,
                  render = I('{ option: function(item, escape) { return "<div>" + escape(item.label) + "</div>"; }, item: function(item, escape) { return "<div>" + escape(item.label) + "</div>"; } }'),
                  load = I('function(query, callback) {
                    if (!query || query.length < 3) return callback();
                    $.getJSON("https://nominatim.openstreetmap.org/search", {
                      q: query + " New York City", format: "json", limit: 5
                    }, function(data) {
                      callback(data.map(function(d) {
                        return { value: d.lat + "|" + d.lon + "|" + d.display_name, label: d.display_name };
                      }));
                    }).fail(function() { callback(); });
                  }')
                )
              ),
              selectInput("route_vehicle", "Vehicle Type",
                          choices = VEHICLE_CHOICES),
              sliderInput("route_hour", "Hour of Day",
                          min = 0, max = 23, value = 8, step = 1),
              selectInput("route_day", "Day of Week",
                          choices = DAY_CHOICES),
              selectInput("route_month", "Month",
                          choices = MONTH_CHOICES),
              actionButton("analyse_route_btn", "Analyse Route",
                           icon = icon("route"))
            )
          ),
          column(width = 8,
            box(title = NULL, width = NULL, solidHeader = FALSE,
              leafletOutput("route_map", height = "520px")
            )
          )
        ),

        # Row 2: Results (hidden until analysis completes)
        shinyjs::hidden(
          div(id = "route_results",
            fluidRow(
              box(title = "Risk Assessment", width = 4, solidHeader = FALSE,
                plotlyOutput("risk_gauge", height = "220px"),
                uiOutput("risk_stats")
              ),
              box(title = "Route Intelligence", width = 8, solidHeader = FALSE,
                uiOutput("route_threats")
              )
            )
          )
        ),

        # Row 3: Model Performance (always visible)
        fluidRow(
          tabBox(title = "Model Performance", width = 12, id = "model_tabs",
            tabPanel("ROC Curve",
              plotlyOutput("model_roc", height = "340px")),
            tabPanel("Confusion Matrix",
              plotlyOutput("model_conf_mat", height = "340px")),
            tabPanel("Variable Importance",
              plotlyOutput("model_var_imp", height = "340px")),
            tabPanel("Calibration",
              plotlyOutput("model_calibration", height = "340px"))
          )
        )
      )
    ) # end tabItems
  ) # end dashboardBody
) # end dashboardPage
