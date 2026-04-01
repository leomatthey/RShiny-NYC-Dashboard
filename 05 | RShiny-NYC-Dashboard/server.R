# server.R — NYC Traffic Accidents 2020 Dashboard
# ============================================================================

server <- function(input, output, session) {

  # Helpers ====

  ## Apply dark Plotly layout to a figure ----
  apply_dark_theme <- function(fig, ...) {
    fig %>%
      layout(
        paper_bgcolor = PLOTLY_LAYOUT$paper_bgcolor,
        plot_bgcolor  = PLOTLY_LAYOUT$plot_bgcolor,
        font          = PLOTLY_LAYOUT$font,
        legend        = PLOTLY_LAYOUT$legend,
        ...
      ) %>%
      config(displayModeBar = TRUE, displaylogo = FALSE,
             modeBarButtonsToRemove = c("lasso2d", "select2d")) %>%
      layout(
        xaxis = PLOTLY_XAXIS,
        yaxis = PLOTLY_YAXIS
      )
  }

  ## Plotly config shortcut ----
  day_labels  <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
  hour_labels <- sprintf("%02d:00", 0:23)
  month_labels <- c("Jan","Feb","Mar","Apr","May","Jun",
                     "Jul","Aug","Sep","Oct","Nov","Dec")

  # Reactive: Filtered Data ====

  filtered_df <- reactive({
    filt <- df

    # Hour range (guard against NULL during init)
    hr <- input$hour_range
    if (!is.null(hr)) {
      filt <- filt %>% filter(HOUR >= hr[1], HOUR <= hr[2])
    }

    # Borough
    boro <- input$borough
    if (!is.null(boro) && length(boro) > 0) {
      filt <- filt %>% filter(BOROUGH %in% boro)
    } else if (!is.null(boro)) {
      filt <- filt %>% filter(FALSE)
    }

    # Severity
    sev <- input$severity
    if (!is.null(sev) && length(sev) > 0) {
      filt <- filt %>% filter(SEVERITY_LABEL %in% sev)
    } else if (!is.null(sev)) {
      filt <- filt %>% filter(FALSE)
    }

    # Month range
    mo <- input$month_range
    if (!is.null(mo)) {
      filt <- filt %>% filter(MONTH_NUM >= mo[1], MONTH_NUM <= mo[2])
    }

    # Commuter type
    ct <- input$commuter_type
    if (!is.null(ct)) {
      if (ct == "Pedestrian") {
        filt <- filt %>% filter(PED_INVOLVED)
      } else if (ct == "Cyclist") {
        filt <- filt %>% filter(CYC_INVOLVED)
      } else if (ct == "Motorist") {
        filt <- filt %>% filter(MOT_INVOLVED)
      }
    }

    filt
  })

  ## Update crash count badge ----
  observe({
    n <- nrow(filtered_df())
    session$sendCustomMessage("update_crash_count", n)
  })

  ## Hide sidebar filters on Route Risk tab ----
  observeEvent(input$tabs, {
    if (input$tabs == "predictor") {
      shinyjs::hide("sidebar-filters")
    } else {
      shinyjs::show("sidebar-filters")
    }
  })

  ## Reset filters ----
  observeEvent(input$reset_filters, {
    updateSliderInput(session, "hour_range", value = c(0, 23))
    updatePickerInput(session, "borough",    selected = BOROUGH_CHOICES)
    updatePickerInput(session, "severity",   selected = SEVERITY_CHOICES)
    updateSliderInput(session, "month_range", value = c(1, MAX_MONTH))
    updatePickerInput(session, "commuter_type", selected = "All")
  })

  # ══════════════════════════════════════════════════════════════════════════
  # Tab 1: Overview ====
  # ══════════════════════════════════════════════════════════════════════════

  ## KPI Boxes ----
  output$kpi_crashes <- renderValueBox({
    d <- filtered_df()
    valueBox(
      value    = format(nrow(d), big.mark = ","),
      subtitle = "Total Crashes",
      icon     = icon("car-crash"),
      color    = "red"
    )
  })

  output$kpi_injured <- renderValueBox({
    d <- filtered_df()
    valueBox(
      value    = format(sum(d$PERSONS_INJURED, na.rm = TRUE), big.mark = ","),
      subtitle = "Persons Injured",
      icon     = icon("ambulance"),
      color    = "orange"
    )
  })

  output$kpi_fatalities <- renderValueBox({
    d <- filtered_df()
    valueBox(
      value    = format(sum(d$PERSONS_KILLED, na.rm = TRUE), big.mark = ","),
      subtitle = "Fatalities",
      icon     = icon("exclamation-triangle"),
      color    = "purple"
    )
  })

  output$kpi_injury_rate <- renderValueBox({
    d <- filtered_df()
    rate <- if (nrow(d) > 0) round(mean(d$ANY_INJURY) * 100, 1) else 0
    valueBox(
      value    = paste0(rate, "%"),
      subtitle = "Injury Rate",
      icon     = icon("chart-line"),
      color    = "blue"
    )
  })

  ## Borough Comparison (grouped horizontal bars: Crashes, Injured, Killed) ----
  output$overview_borough <- renderPlotly({
    d <- filtered_df() %>%
      filter(BOROUGH %in% BOROUGH_ORDER) %>%
      group_by(BOROUGH) %>%
      summarise(
        Crashes = n(),
        Injured = sum(PERSONS_INJURED, na.rm = TRUE),
        Killed  = sum(PERSONS_KILLED, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(desc(Crashes)) %>%
      mutate(BOROUGH = factor(BOROUGH, levels = rev(BOROUGH)))

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    plot_ly(d) %>%
      add_bars(x = ~Crashes, y = ~BOROUGH, orientation = "h",
               name = "Crashes",
               marker = list(color = "#3498db", line = list(width = 0)),
               hovertemplate = "<b>%{y}</b><br>Crashes: %{x:,}<extra></extra>") %>%
      add_bars(x = ~Injured, y = ~BOROUGH, orientation = "h",
               name = "Injured",
               marker = list(color = "#e67e22", line = list(width = 0)),
               hovertemplate = "<b>%{y}</b><br>Injured: %{x:,}<extra></extra>") %>%
      add_bars(x = ~Killed, y = ~BOROUGH, orientation = "h",
               name = "Killed",
               marker = list(color = "#e74c3c", line = list(width = 0)),
               hovertemplate = "<b>%{y}</b><br>Killed: %{x:,}<extra></extra>") %>%
      layout(
        xaxis   = c(PLOTLY_XAXIS, list(title = "Count")),
        yaxis   = c(PLOTLY_YAXIS, list(title = "")),
        barmode = "group",
        legend  = list(orientation = "h", y = -0.2, bgcolor = "rgba(0,0,0,0)"),
        margin  = list(l = 100, r = 20, t = 10, b = 50)
      ) %>%
      apply_dark_theme()
  })

  ## Victim Type Donut ----
  output$overview_victim_donut <- renderPlotly({
    d <- filtered_df()
    ped_inj <- sum(d$PED_INJURED, na.rm = TRUE)
    cyc_inj <- sum(d$CYC_INJURED, na.rm = TRUE)
    mot_inj <- sum(d$MOT_INJURED, na.rm = TRUE)
    total   <- ped_inj + cyc_inj + mot_inj

    plot_ly(
      labels = c("Vehicle Occupants (drivers & passengers)", "Pedestrians", "Cyclists"),
      values = c(mot_inj, ped_inj, cyc_inj),
      type   = "pie",
      hole   = 0.6,
      marker = list(
        colors = c("#3498db", "#e74c3c", "#27ae60"),
        line   = list(color = "#1c2128", width = 2)
      ),
      textinfo  = "none",
      hovertemplate = "<b>%{label}</b><br>Injured: %{value:,}<br>%{percent}<extra></extra>"
    ) %>%
      layout(
        annotations = list(
          list(text = paste0("<b>", format(total, big.mark = ","), "</b><br>",
                             "<span style='font-size:10px'>total injured</span>"),
               x = 0.5, y = 0.5, showarrow = FALSE,
               font = list(size = 15, color = "#e6edf3"))
        ),
        showlegend = TRUE,
        legend = list(orientation = "h", y = -0.1, bgcolor = "rgba(0,0,0,0)"),
        margin = list(l = 0, r = 0, t = 10, b = 30)
      ) %>%
      apply_dark_theme()
  })

  ## Hourly Distribution (24h bars, rush-hour highlighted) ----
  output$overview_hourly <- renderPlotly({
    d <- filtered_df() %>%
      group_by(HOUR) %>%
      summarise(crashes = n(), .groups = "drop") %>%
      complete(HOUR = 0:23, fill = list(crashes = 0))

    rush_hours <- c(7, 8, 9, 16, 17, 18, 19)
    bar_colors <- ifelse(d$HOUR %in% rush_hours, "#e74c3c", "#3498db")

    plot_ly(d, x = ~HOUR, y = ~crashes, type = "bar",
            marker = list(color = bar_colors, line = list(width = 0)),
            hovertemplate = "<b>%{x}:00</b><br>Crashes: %{y:,}<extra></extra>") %>%
      layout(
        xaxis = c(PLOTLY_XAXIS, list(title = "Hour of Day", dtick = 2,
                                      tickvals = 0:23, ticktext = hour_labels)),
        yaxis = c(PLOTLY_YAXIS, list(title = "Crashes")),
        margin = list(l = 50, r = 20, t = 10, b = 50),
        shapes = list(
          list(type = "rect", x0 = 6.5, x1 = 9.5, y0 = 0, y1 = 1,
               yref = "paper", fillcolor = "rgba(231,76,60,0.08)",
               line = list(width = 0), layer = "below"),
          list(type = "rect", x0 = 15.5, x1 = 19.5, y0 = 0, y1 = 1,
               yref = "paper", fillcolor = "rgba(231,76,60,0.08)",
               line = list(width = 0), layer = "below")
        ),
        annotations = list(
          list(x = 8, y = 1.06, yref = "paper", text = "AM Rush",
               showarrow = FALSE, font = list(size = 10, color = "#e74c3c")),
          list(x = 17.5, y = 1.06, yref = "paper", text = "PM Rush",
               showarrow = FALSE, font = list(size = 10, color = "#e74c3c"))
        )
      ) %>%
      apply_dark_theme()
  })

  ## Severity by Borough (100% stacked bar) ----
  output$overview_severity_borough <- renderPlotly({
    d <- filtered_df() %>%
      filter(BOROUGH %in% BOROUGH_ORDER) %>%
      count(BOROUGH, SEVERITY_LABEL) %>%
      group_by(BOROUGH) %>%
      mutate(pct = round(n / sum(n) * 100, 1)) %>%
      ungroup() %>%
      mutate(
        SEVERITY_LABEL = factor(SEVERITY_LABEL, levels = SEVERITY_ORDER),
        BOROUGH = factor(BOROUGH, levels = BOROUGH_ORDER)
      )

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    fig <- plot_ly()
    for (sev in SEVERITY_ORDER) {
      sub <- d %>% filter(SEVERITY_LABEL == sev)
      fig <- fig %>%
        add_bars(data = sub, x = ~BOROUGH, y = ~pct, name = sev,
                 marker = list(color = SEVERITY_COLORS[sev], line = list(width = 0)),
                 hovertemplate = paste0("<b>%{x}</b><br>", sev,
                                       ": %{y:.1f}%<extra></extra>"))
    }

    fig %>%
      layout(
        barmode = "stack",
        xaxis   = c(PLOTLY_XAXIS, list(title = "")),
        yaxis   = c(PLOTLY_YAXIS, list(title = "% of Crashes", range = c(0, 100))),
        legend  = list(orientation = "h", y = -0.2, bgcolor = "rgba(0,0,0,0)",
                        font = list(size = 10)),
        margin  = list(l = 50, r = 20, t = 10, b = 60)
      ) %>%
      apply_dark_theme()
  })

  # ══════════════════════════════════════════════════════════════════════════
  # Tab 2: Interactive Map ====
  # ══════════════════════════════════════════════════════════════════════════

  ## Base map (rendered once) ----
  output$crash_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.DarkMatter,
                       options = providerTileOptions(noWrap = TRUE)) %>%
      setView(lng = -73.935, lat = 40.730, zoom = 11)
  })

  ## Map layers via leafletProxy ----
  observe({
    req(input$crash_map_bounds)
    d <- filtered_df() %>% filter(VALID_COORDS)

    proxy <- leafletProxy("crash_map") %>%
      clearHeatmap() %>%
      clearGroup("crash_markers")

    if (nrow(d) == 0) return(proxy)

    if (input$map_mode == "Heatmap") {
      # Heatmap: intensity weighted by injuries
      heat_data <- d %>%
        select(LATITUDE, LONGITUDE, PERSONS_INJURED) %>%
        mutate(intensity = pmax(PERSONS_INJURED, 0.5))

      proxy %>%
        addHeatmap(
          data      = heat_data,
          lat       = ~LATITUDE,
          lng       = ~LONGITUDE,
          intensity = ~intensity,
          blur      = 15,
          max       = 1,
          radius    = 14,
          gradient  = c("transparent", "#fed976", "#fd8d3c", "#e31a1c", "#bd0026")
        )

    } else {
      # Markers: colored by severity, with popups
      sev_pal <- colorFactor(
        palette = unname(SEVERITY_COLORS[SEVERITY_ORDER]),
        domain  = SEVERITY_ORDER
      )

      # Sample to max 5000 for performance
      if (nrow(d) > 5000) d <- d %>% slice_sample(n = 5000)

      proxy %>%
        addCircleMarkers(
          data         = d,
          lat          = ~LATITUDE,
          lng          = ~LONGITUDE,
          radius       = 4,
          color        = ~sev_pal(SEVERITY_LABEL),
          fillColor    = ~sev_pal(SEVERITY_LABEL),
          fillOpacity  = 0.7,
          stroke       = FALSE,
          group        = "crash_markers",
          clusterOptions = markerClusterOptions(
            iconCreateFunction = JS(
              "function(cluster) {
                var n = cluster.getChildCount();
                var size = n < 100 ? 'small' : n < 500 ? 'medium' : 'large';
                return L.divIcon({
                  html: '<div><span>' + n + '</span></div>',
                  className: 'marker-cluster marker-cluster-' + size,
                  iconSize: L.point(40, 40)
                });
              }"
            )
          ),
          popup = ~paste0(
            "<div style='font-family:Inter,sans-serif;font-size:12px;color:#e6edf3;",
            "background:#1c2128;padding:10px;border-radius:8px;min-width:180px'>",
            "<b style='color:", sev_pal(SEVERITY_LABEL), "'>", SEVERITY_LABEL, "</b><br>",
            "<span style='color:#8b949e'>Date:</span> ", CRASH_DATE, "<br>",
            "<span style='color:#8b949e'>Time:</span> ", CRASH_TIME, "<br>",
            "<span style='color:#8b949e'>Borough:</span> ", BOROUGH, "<br>",
            "<span style='color:#8b949e'>Street:</span> ",
            ifelse(is.na(ON_STREET_NAME) | ON_STREET_NAME == "", "N/A", ON_STREET_NAME), "<br>",
            "<span style='color:#8b949e'>Factor:</span> ", PRIMARY_FACTOR, "<br>",
            "<span style='color:#8b949e'>Vehicle:</span> ", PRIMARY_VEHICLE,
            "</div>"
          )
        )
    }
  })

  ## Map stats sidebar ----
  output$map_stats <- renderUI({
    d <- filtered_df() %>% filter(VALID_COORDS)
    n_map <- nrow(d)
    n_inj <- sum(d$PERSONS_INJURED, na.rm = TRUE)
    n_fat <- sum(d$PERSONS_KILLED, na.rm = TRUE)

    tags$div(
      style = "font-size: 1rem; color: #e6edf3;",
      tags$div(style = "margin-bottom:8px;",
        tags$span(style = "color:#8b949e;", "Points: "),
        tags$b(format(n_map, big.mark = ","))
      ),
      tags$div(style = "margin-bottom:8px;",
        tags$span(style = "color:#8b949e;", "Injured: "),
        tags$b(style = "color:#e67e22;", format(n_inj, big.mark = ","))
      ),
      tags$div(
        tags$span(style = "color:#8b949e;", "Fatal: "),
        tags$b(style = "color:#e74c3c;", format(n_fat, big.mark = ","))
      )
    )
  })

  ## Most Dangerous Streets (reactive for DT + map link) ----
  dangerous_streets_data <- reactive({
    d <- filtered_df() %>%
      filter(!is.na(ON_STREET_NAME), ON_STREET_NAME != "")

    d %>%
      group_by(Street = ON_STREET_NAME) %>%
      summarise(
        Crashes        = n(),
        Injured        = sum(PERSONS_INJURED, na.rm = TRUE),
        Killed         = sum(PERSONS_KILLED, na.rm = TRUE),
        Injury_Rate    = round(mean(ANY_INJURY) * 100, 1),
        `Top Cause`    = {
          tbl <- sort(table(PRIMARY_FACTOR), decreasing = TRUE)
          cause <- names(tbl)[1]
          if (cause == "Unspecified" && length(tbl) > 1) cause <- names(tbl)[2]
          cause
        },
        hotspot_lat = {
          valid <- VALID_COORDS & !is.na(LATITUDE) & !is.na(LONGITUDE)
          if (sum(valid) == 0) NA_real_
          else {
            key <- paste(round(LATITUDE[valid], 3), round(LONGITUDE[valid], 3))
            best <- names(which.max(table(key)))
            as.numeric(strsplit(best, " ")[[1]][1])
          }
        },
        hotspot_lng = {
          valid <- VALID_COORDS & !is.na(LATITUDE) & !is.na(LONGITUDE)
          if (sum(valid) == 0) NA_real_
          else {
            key <- paste(round(LATITUDE[valid], 3), round(LONGITUDE[valid], 3))
            best <- names(which.max(table(key)))
            as.numeric(strsplit(best, " ")[[1]][2])
          }
        },
        .groups        = "drop"
      ) %>%
      arrange(desc(Crashes)) %>%
      head(10)
  })

  ## Most Dangerous Streets (DT) ----
  output$dangerous_streets <- renderDT({
    streets <- dangerous_streets_data() %>%
      select(Street, Crashes, Injured, Killed, Injury_Rate, `Top Cause`)

    datatable(streets,
              options = list(
                dom        = "t",
                pageLength = 10,
                ordering   = TRUE,
                scrollX    = TRUE,
                columnDefs = list(list(className = "dt-center", targets = 1:4))
              ),
              rownames  = FALSE,
              selection = "single",
              class     = "compact stripe") %>%
      formatRound(columns = c("Crashes", "Injured", "Killed"), digits = 0, mark = ",") %>%
      formatStyle("Injury_Rate",
                  background = styleColorBar(c(0, 100), "#e74c3c40"),
                  backgroundSize = "98% 80%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "left center")
  })

  ## Fly map to selected street ----
  observeEvent(input$dangerous_streets_rows_selected, ignoreNULL = FALSE, {
    row_idx <- input$dangerous_streets_rows_selected

    # Deselected — clear highlight
    if (is.null(row_idx) || length(row_idx) == 0) {
      leafletProxy("crash_map") %>% clearGroup("street_highlight")
      return()
    }

    street <- dangerous_streets_data()[row_idx, ]
    if (is.na(street$hotspot_lat) || is.na(street$hotspot_lng)) return()

    popup_html <- paste0(
      "<div style='font-family:Inter,sans-serif;font-size:12px;color:#e6edf3;",
      "background:#1c2128;padding:12px 14px;border-radius:8px;min-width:200px;",
      "border-left:3px solid #e74c3c'>",
      "<b style='font-size:13px;color:#e74c3c'>", street$Street, "</b>",
      "<table style='margin-top:8px;border-spacing:0 4px;width:100%'>",
      "<tr><td style='color:#8b949e'>Crashes</td><td style='text-align:right;font-weight:600'>",
        format(street$Crashes, big.mark = ","), "</td></tr>",
      "<tr><td style='color:#8b949e'>Injured</td><td style='text-align:right;font-weight:600;color:#e67e22'>",
        format(street$Injured, big.mark = ","), "</td></tr>",
      "<tr><td style='color:#8b949e'>Killed</td><td style='text-align:right;font-weight:600;color:#e74c3c'>",
        street$Killed, "</td></tr>",
      "<tr><td style='color:#8b949e'>Injury Rate</td><td style='text-align:right;font-weight:600'>",
        street$Injury_Rate, "%</td></tr>",
      "<tr><td style='color:#8b949e'>Top Cause</td><td style='text-align:right;font-weight:600;font-size:11px'>",
        street$`Top Cause`, "</td></tr>",
      "</table></div>"
    )

    street_icon <- makeAwesomeIcon(
      icon        = "exclamation",
      iconColor   = "#ffffff",
      markerColor = "red",
      library     = "fa"
    )

    leafletProxy("crash_map") %>%
      clearGroup("street_highlight") %>%
      flyTo(lng = street$hotspot_lng, lat = street$hotspot_lat, zoom = 15) %>%
      addAwesomeMarkers(
        lng     = street$hotspot_lng,
        lat     = street$hotspot_lat,
        icon    = street_icon,
        group   = "street_highlight",
        popup   = popup_html,
        options = markerOptions(riseOnHover = TRUE)
      )

    # Auto-open popup after flyTo completes
    shinyjs::delay(800, {
      leafletProxy("crash_map") %>%
        addPopups(
          lng   = street$hotspot_lng,
          lat   = street$hotspot_lat,
          popup = popup_html,
          group = "street_highlight"
        )
    })
  })

  # ══════════════════════════════════════════════════════════════════════════
  # Tab 3: Time Analysis ====
  # ══════════════════════════════════════════════════════════════════════════

  ## Hour x Day-of-Week Heatmap ----
  output$time_heatmap <- renderPlotly({
    d <- filtered_df() %>%
      count(DAY_OF_WEEK_NUM, HOUR) %>%
      complete(DAY_OF_WEEK_NUM = 1:7, HOUR = 0:23, fill = list(n = 0))

    # Pivot to matrix
    mat <- d %>%
      arrange(DAY_OF_WEEK_NUM, HOUR) %>%
      pivot_wider(names_from = HOUR, values_from = n, values_fill = 0) %>%
      arrange(DAY_OF_WEEK_NUM) %>%
      select(-DAY_OF_WEEK_NUM)

    plot_ly(
      z    = as.matrix(mat),
      x    = hour_labels,
      y    = day_labels,
      type = "heatmap",
      colorscale = "Viridis",
      hoverongaps = FALSE,
      hovertemplate = "<b>%{y} %{x}</b><br>Crashes: %{z}<extra></extra>"
    ) %>%
      layout(
        xaxis = c(PLOTLY_XAXIS, list(title = "", tickangle = -45)),
        yaxis = c(PLOTLY_YAXIS, list(title = "", autorange = "reversed")),
        margin = list(l = 50, r = 20, t = 10, b = 60),
        # Rush hour annotation rectangles
        shapes = list(
          list(type = "rect", x0 = 6.5, x1 = 9.5, y0 = -0.5, y1 = 6.5,
               fillcolor = "rgba(231,76,60,0.1)", line = list(color = "rgba(231,76,60,0.3)", width = 1)),
          list(type = "rect", x0 = 15.5, x1 = 19.5, y0 = -0.5, y1 = 6.5,
               fillcolor = "rgba(231,76,60,0.1)", line = list(color = "rgba(231,76,60,0.3)", width = 1))
        ),
        annotations = list(
          list(x = "08:00", y = -0.8, text = "AM Rush", showarrow = FALSE,
               font = list(size = 10, color = "#e74c3c")),
          list(x = "17:00", y = -0.8, text = "PM Rush", showarrow = FALSE,
               font = list(size = 10, color = "#e74c3c"))
        )
      ) %>%
      apply_dark_theme()
  })

  ## Day-of-Week Bars + Injury Rate Line (dual axis) ----
  output$time_dow <- renderPlotly({
    d <- filtered_df() %>%
      mutate(DAY_OF_WEEK = factor(DAY_OF_WEEK,
                                   levels = c("Monday","Tuesday","Wednesday",
                                              "Thursday","Friday","Saturday","Sunday"))) %>%
      group_by(DAY_OF_WEEK) %>%
      summarise(
        crashes     = n(),
        injury_rate = round(mean(ANY_INJURY) * 100, 1),
        .groups     = "drop"
      )

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    # Bar colors: weekend = red, weekday = blue
    bar_cols <- ifelse(d$DAY_OF_WEEK %in% c("Saturday", "Sunday"), "#e74c3c", "#3498db")

    plot_ly(d) %>%
      add_bars(x = ~DAY_OF_WEEK, y = ~crashes, name = "Crashes",
               marker = list(color = bar_cols, line = list(width = 0)),
               hovertemplate = "<b>%{x}</b><br>Crashes: %{y:,}<extra></extra>") %>%
      add_trace(x = ~DAY_OF_WEEK, y = ~injury_rate, name = "Injury Rate %",
                type = "scatter", mode = "lines+markers",
                yaxis = "y2",
                line = list(color = "#f39c12", width = 2),
                marker = list(color = "#f39c12", size = 7),
                hovertemplate = "<b>%{x}</b><br>Injury Rate: %{y:.1f}%<extra></extra>") %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "")),
        yaxis  = c(PLOTLY_YAXIS, list(title = "Crashes")),
        yaxis2 = list(title = "Injury Rate %", overlaying = "y", side = "right",
                       showgrid = FALSE, color = "#f39c12",
                       gridcolor = "transparent", zerolinecolor = "transparent"),
        legend = list(orientation = "h", y = -0.25, bgcolor = "rgba(0,0,0,0)"),
        margin = list(l = 50, r = 60, t = 10, b = 60),
        # Weekend shading
        shapes = list(
          list(type = "rect", x0 = 4.5, x1 = 6.5, y0 = 0, y1 = 1,
               yref = "paper", fillcolor = "rgba(231,76,60,0.06)",
               line = list(width = 0), layer = "below")
        )
      ) %>%
      apply_dark_theme()
  })

  ## Time of Day by Victim Type (100% stacked bar) ----
  output$time_victim <- renderPlotly({
    d <- filtered_df() %>%
      group_by(TIME_PERIOD) %>%
      summarise(
        Pedestrians       = sum(PED_INJURED, na.rm = TRUE),
        Cyclists          = sum(CYC_INJURED, na.rm = TRUE),
        `Vehicle Occupants` = sum(MOT_INJURED, na.rm = TRUE),
        .groups           = "drop"
      ) %>%
      mutate(
        total = Pedestrians + Cyclists + `Vehicle Occupants`,
        TIME_PERIOD = factor(TIME_PERIOD, levels = c("Morning", "Afternoon", "Evening", "Night"))
      ) %>%
      filter(total > 0) %>%
      mutate(across(c(Pedestrians, Cyclists, `Vehicle Occupants`), ~ round(. / total * 100, 1)))

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    victim_colors <- c(`Vehicle Occupants` = "#3498db", Pedestrians = "#e74c3c", Cyclists = "#27ae60")

    fig <- plot_ly()
    for (v in names(victim_colors)) {
      fig <- fig %>%
        add_bars(data = d, x = ~TIME_PERIOD, y = as.formula(paste0("~`", v, "`")),
                 name = v, marker = list(color = victim_colors[v], line = list(width = 0)),
                 hovertemplate = paste0("<b>%{x}</b><br>", v, ": %{y:.1f}%<extra></extra>"))
    }

    fig %>%
      layout(
        barmode = "stack",
        xaxis   = c(PLOTLY_XAXIS, list(title = "")),
        yaxis   = c(PLOTLY_YAXIS, list(title = "% of Injured", range = c(0, 100))),
        legend  = list(orientation = "h", y = -0.25, bgcolor = "rgba(0,0,0,0)"),
        margin  = list(l = 50, r = 20, t = 10, b = 60)
      ) %>%
      apply_dark_theme()
  })

  ## Monthly Crash Volume (bar chart) ----
  output$time_monthly <- renderPlotly({
    d <- filtered_df() %>%
      count(MONTH_NUM) %>%
      complete(MONTH_NUM = 1:MAX_MONTH, fill = list(n = 0)) %>%
      mutate(label = month_labels[MONTH_NUM])

    plot_ly(d, x = ~label, y = ~n, type = "bar",
            marker = list(color = "#3498db", line = list(width = 0)),
            hovertemplate = "<b>%{x}</b><br>Crashes: %{y:,}<extra></extra>") %>%
      layout(
        xaxis = c(PLOTLY_XAXIS, list(title = "",
                   categoryorder = "array", categoryarray = month_labels[1:MAX_MONTH])),
        yaxis = c(PLOTLY_YAXIS, list(title = "Crashes")),
        margin = list(l = 50, r = 20, t = 10, b = 50)
      ) %>%
      apply_dark_theme()
  })

  ## Hour x Borough Heatmap ----
  output$time_borough_heatmap <- renderPlotly({
    d <- filtered_df() %>%
      filter(BOROUGH %in% BOROUGH_ORDER) %>%
      count(HOUR, BOROUGH) %>%
      complete(HOUR = 0:23, BOROUGH = BOROUGH_ORDER, fill = list(n = 0))

    mat <- d %>%
      mutate(BOROUGH = factor(BOROUGH, levels = BOROUGH_ORDER)) %>%
      arrange(BOROUGH, HOUR) %>%
      pivot_wider(names_from = HOUR, values_from = n, values_fill = 0) %>%
      arrange(BOROUGH) %>%
      select(-BOROUGH)

    plot_ly(
      z    = as.matrix(mat),
      x    = hour_labels,
      y    = BOROUGH_ORDER,
      type = "heatmap",
      colorscale = "Viridis",
      hoverongaps = FALSE,
      hovertemplate = "<b>%{y} @ %{x}</b><br>Crashes: %{z}<extra></extra>"
    ) %>%
      layout(
        xaxis = c(PLOTLY_XAXIS, list(title = "", tickangle = -45)),
        yaxis = c(PLOTLY_YAXIS, list(title = "")),
        margin = list(l = 100, r = 20, t = 10, b = 60)
      ) %>%
      apply_dark_theme()
  })

  # ══════════════════════════════════════════════════════════════════════════
  # Tab 4: Causes & Vehicles ====
  # ══════════════════════════════════════════════════════════════════════════

  ## Top 15 Contributing Factors (horizontal bar, Unspecified excluded) ----
  output$causes_top_factors <- renderPlotly({
    d <- filtered_df() %>%
      filter(FACTOR_CATEGORY != "Other / Unknown") %>%
      count(PRIMARY_FACTOR, FACTOR_CATEGORY, sort = TRUE) %>%
      head(15) %>%
      mutate(PRIMARY_FACTOR = factor(PRIMARY_FACTOR, levels = rev(PRIMARY_FACTOR)))

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    bar_colors <- FACTOR_COLORS[as.character(d$FACTOR_CATEGORY)]

    plot_ly(d, y = ~PRIMARY_FACTOR, x = ~n, type = "bar", orientation = "h",
            marker = list(color = bar_colors, line = list(width = 0)),
            customdata = ~FACTOR_CATEGORY,
            hovertemplate = "<b>%{y}</b><br>Crashes: %{x:,}<br>Category: %{customdata}<extra></extra>") %>%
      layout(
        xaxis = c(PLOTLY_XAXIS, list(title = "Number of Crashes")),
        yaxis = c(PLOTLY_YAXIS, list(title = "", tickfont = list(size = 10))),
        margin = list(l = 180, r = 20, t = 10, b = 50)
      ) %>%
      apply_dark_theme()
  })

  ## Factor Category Trends (monthly lines) ----
  output$causes_factor_time <- renderPlotly({
    # Use pre-aggregated table, but also allow filter interaction
    d <- filtered_df() %>%
      filter(FACTOR_CATEGORY != "Other / Unknown") %>%
      count(MONTH_NUM, FACTOR_CATEGORY) %>%
      complete(MONTH_NUM = 1:MAX_MONTH,
               FACTOR_CATEGORY = setdiff(names(FACTOR_COLORS), "Other / Unknown"),
               fill = list(n = 0)) %>%
      mutate(label = month_labels[MONTH_NUM])

    fig <- plot_ly()
    categories <- unique(d$FACTOR_CATEGORY)
    for (cat in categories) {
      sub <- d %>% filter(FACTOR_CATEGORY == cat) %>% arrange(MONTH_NUM)
      col <- FACTOR_COLORS[cat]
      if (is.na(col)) col <- "#888"
      fig <- fig %>%
        add_trace(data = sub, x = ~label, y = ~n, name = cat,
                  type = "scatter", mode = "lines+markers",
                  line = list(color = col, width = 2),
                  marker = list(color = col, size = 5),
                  hovertemplate = paste0("<b>", cat, "</b><br>%{x}: %{y:,} crashes<extra></extra>"))
    }

    fig %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "",
                    categoryorder = "array", categoryarray = month_labels[1:MAX_MONTH])),
        yaxis  = c(PLOTLY_YAXIS, list(title = "Crashes")),
        legend = list(font = list(size = 9), bgcolor = "rgba(0,0,0,0)",
                       y = 0.5),
        margin = list(l = 50, r = 20, t = 10, b = 50)
      ) %>%
      apply_dark_theme()
  })

  ## Vehicle Type x Severity (100% stacked bar, sorted by fatal+severe rate) ----
  output$causes_vehicle_severity <- renderPlotly({
    d <- filtered_df() %>%
      count(PRIMARY_VEHICLE, SEVERITY_LABEL) %>%
      group_by(PRIMARY_VEHICLE) %>%
      mutate(pct = round(n / sum(n) * 100, 1)) %>%
      ungroup() %>%
      mutate(SEVERITY_LABEL = factor(SEVERITY_LABEL, levels = SEVERITY_ORDER))

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    # Sort vehicles by fatal+severe rate
    severe_rate <- d %>%
      filter(SEVERITY_LABEL %in% c("Fatal", "Severe Injury")) %>%
      group_by(PRIMARY_VEHICLE) %>%
      summarise(severe_pct = sum(pct), .groups = "drop") %>%
      arrange(desc(severe_pct))

    veh_order <- severe_rate$PRIMARY_VEHICLE

    fig <- plot_ly()
    for (sev in SEVERITY_ORDER) {
      sub <- d %>% filter(SEVERITY_LABEL == sev)
      fig <- fig %>%
        add_bars(data = sub, x = ~PRIMARY_VEHICLE, y = ~pct, name = sev,
                 marker = list(color = SEVERITY_COLORS[sev], line = list(width = 0)),
                 hovertemplate = paste0("<b>%{x}</b><br>", sev,
                                       ": %{y:.1f}%<extra></extra>"))
    }

    fig %>%
      layout(
        barmode = "stack",
        xaxis   = c(PLOTLY_XAXIS, list(title = "", tickangle = -20,
                     categoryorder = "array", categoryarray = veh_order,
                     tickfont = list(size = 10))),
        yaxis   = c(PLOTLY_YAXIS, list(title = "% of Crashes", range = c(0, 100))),
        legend  = list(orientation = "h", y = -0.35, bgcolor = "rgba(0,0,0,0)",
                        font = list(size = 10)),
        margin  = list(l = 50, r = 20, t = 10, b = 80)
      ) %>%
      apply_dark_theme()
  })

  ## Factor Composition by Vehicle (100% stacked bar) ----
  output$causes_factor_vehicle <- renderPlotly({
    d <- filtered_df() %>%
      filter(FACTOR_CATEGORY != "Other / Unknown") %>%
      count(PRIMARY_VEHICLE, FACTOR_CATEGORY) %>%
      group_by(PRIMARY_VEHICLE) %>%
      mutate(pct = round(n / sum(n) * 100, 1)) %>%
      ungroup()

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    fig <- plot_ly()
    for (cat in names(FACTOR_COLORS)) {
      if (cat == "Other / Unknown") next
      sub <- d %>% filter(FACTOR_CATEGORY == cat)
      if (nrow(sub) == 0) next
      fig <- fig %>%
        add_bars(data = sub, x = ~PRIMARY_VEHICLE, y = ~pct, name = cat,
                 marker = list(color = FACTOR_COLORS[cat], line = list(width = 0)),
                 hovertemplate = paste0("<b>%{x}</b><br>", cat,
                                       ": %{y:.1f}%<extra></extra>"))
    }

    fig %>%
      layout(
        barmode = "stack",
        xaxis   = c(PLOTLY_XAXIS, list(title = "", tickangle = -20,
                     tickfont = list(size = 10))),
        yaxis   = c(PLOTLY_YAXIS, list(title = "% of Crashes", range = c(0, 100))),
        legend  = list(font = list(size = 9), bgcolor = "rgba(0,0,0,0)", y = 0.5),
        margin  = list(l = 50, r = 20, t = 10, b = 80)
      ) %>%
      apply_dark_theme()
  })

  ## Factor Severity Profile (100% stacked bar per factor category) ----
  output$causes_factor_severity <- renderPlotly({
    d <- filtered_df() %>%
      filter(FACTOR_CATEGORY != "Other / Unknown") %>%
      count(FACTOR_CATEGORY, SEVERITY_LABEL) %>%
      group_by(FACTOR_CATEGORY) %>%
      mutate(pct = round(n / sum(n) * 100, 1)) %>%
      ungroup() %>%
      mutate(SEVERITY_LABEL = factor(SEVERITY_LABEL, levels = SEVERITY_ORDER))

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    fig <- plot_ly()
    for (sev in SEVERITY_ORDER) {
      sub <- d %>% filter(SEVERITY_LABEL == sev)
      fig <- fig %>%
        add_bars(data = sub, x = ~FACTOR_CATEGORY, y = ~pct, name = sev,
                 marker = list(color = SEVERITY_COLORS[sev], line = list(width = 0)),
                 hovertemplate = paste0("<b>%{x}</b><br>", sev,
                                       ": %{y:.1f}%<extra></extra>"))
    }

    fig %>%
      layout(
        barmode = "stack",
        xaxis   = c(PLOTLY_XAXIS, list(title = "", tickangle = -30,
                     tickfont = list(size = 10))),
        yaxis   = c(PLOTLY_YAXIS, list(title = "% of Crashes", range = c(0, 100))),
        legend  = list(orientation = "h", y = -0.4, bgcolor = "rgba(0,0,0,0)",
                        font = list(size = 10)),
        margin  = list(l = 50, r = 20, t = 10, b = 100)
      ) %>%
      apply_dark_theme()
  })

  ## Borough Vulnerability (Ped + Cyclist injury rates, grouped bars + line) ----
  output$overview_borough_vulnerability <- renderPlotly({
    d <- filtered_df() %>%
      filter(BOROUGH %in% BOROUGH_ORDER) %>%
      group_by(BOROUGH) %>%
      summarise(
        total      = n(),
        ped_rate   = round(sum(PED_INJURED, na.rm = TRUE) / total * 100, 1),
        cyc_rate   = round(sum(CYC_INJURED, na.rm = TRUE) / total * 100, 1),
        combo_rate = ped_rate + cyc_rate,
        .groups    = "drop"
      ) %>%
      mutate(BOROUGH = factor(BOROUGH, levels = BOROUGH_ORDER))

    if (nrow(d) == 0) return(plotly_empty() %>% apply_dark_theme())

    # Find max borough for annotation
    max_boro <- d %>% filter(combo_rate == max(combo_rate))
    min_boro <- d %>% filter(combo_rate == min(combo_rate))
    annotation_text <- ""
    if (nrow(max_boro) > 0 && nrow(min_boro) > 0) {
      ratio <- round(max_boro$combo_rate[1] / max(min_boro$combo_rate[1], 0.1), 1)
      annotation_text <- paste0(max_boro$BOROUGH[1], " vulnerable road users are ",
                                ratio, "\u00d7 more at risk than ", min_boro$BOROUGH[1])
    }

    plot_ly(d) %>%
      add_bars(x = ~BOROUGH, y = ~ped_rate, name = "Pedestrian",
               marker = list(color = "#e74c3c", line = list(width = 0)),
               hovertemplate = "<b>%{x}</b><br>Ped rate: %{y:.1f}%<extra></extra>") %>%
      add_bars(x = ~BOROUGH, y = ~cyc_rate, name = "Cyclist",
               marker = list(color = "#27ae60", line = list(width = 0)),
               hovertemplate = "<b>%{x}</b><br>Cyc rate: %{y:.1f}%<extra></extra>") %>%
      add_trace(x = ~BOROUGH, y = ~combo_rate, name = "Combined Rate",
                type = "scatter", mode = "lines+markers",
                line = list(color = "#f39c12", width = 2),
                marker = list(color = "#f39c12", size = 8),
                hovertemplate = "<b>%{x}</b><br>Combined: %{y:.1f}%<extra></extra>") %>%
      layout(
        barmode = "group",
        xaxis   = c(PLOTLY_XAXIS, list(title = "")),
        yaxis   = c(PLOTLY_YAXIS, list(title = "Injury Rate per 100 Crashes")),
        legend  = list(orientation = "h", y = -0.25, bgcolor = "rgba(0,0,0,0)"),
        margin  = list(l = 50, r = 20, t = 30, b = 60),
        annotations = list(
          list(text = annotation_text,
               x = 0.5, y = 1.08, xref = "paper", yref = "paper",
               showarrow = FALSE, font = list(size = 10, color = "#8b949e"))
        )
      ) %>%
      apply_dark_theme()
  })

  # ══════════════════════════════════════════════════════════════════════════
  # Tab 5: Route Risk Predictor ====
  # ══════════════════════════════════════════════════════════════════════════

  ## Parse lat/lon from selectize value ----
  # Value format from ORS autocomplete: "lat|lon|display_name"
  # Falls back to tidygeocoder if plain text entered without selecting from dropdown
  parse_coord_value <- function(val) {
    if (grepl("^-?[0-9.]+\\|-?[0-9.]+\\|", val)) {
      parts <- strsplit(val, "\\|")[[1]]
      list(lat  = as.numeric(parts[1]),
           lon  = as.numeric(parts[2]),
           name = paste(parts[-(1:2)], collapse = "|"))
    } else {
      res <- tidygeocoder::geo(val, method = "osm", full_results = FALSE, quiet = TRUE)
      list(lat = res$lat[1], lon = res$long[1], name = val)
    }
  }

  ## Base route map ----
  output$route_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.DarkMatter,
                       options = providerTileOptions(noWrap = TRUE)) %>%
      setView(lng = -73.935, lat = 40.730, zoom = 11)
  })

  ## Core reactive: route analysis ----
  route_analysis <- eventReactive(input$analyse_route_btn, {
    req(nchar(trimws(input$route_origin)) > 0,
        nchar(trimws(input$route_dest))   > 0)

    withProgress(message = "Analysing route...", value = 0, {

      # Step 1: Resolve coordinates from selectize values
      incProgress(0.1, detail = "Resolving addresses")
      origin <- parse_coord_value(trimws(input$route_origin))
      dest   <- parse_coord_value(trimws(input$route_dest))
      validate(need(
        !is.na(origin$lat) & !is.na(dest$lat),
        "Could not resolve one or both addresses. Try selecting from the dropdown suggestions."
      ))

      # Step 2: Route via ORS (driving profile for general routing)
      incProgress(0.3, detail = "Computing route")
      ors_profile <- "driving-car"
      route_sf <- tryCatch({
        openrouteservice::ors_directions(
          coordinates = list(c(origin$lon, origin$lat), c(dest$lon, dest$lat)),
          profile     = ors_profile,
          output      = "sf"
        )
      }, error = function(e) {
        validate(need(FALSE, paste0(
          "Route computation failed: ", conditionMessage(e),
          ". Check that the ORS_API_KEY is set and addresses are within NYC."
        )))
      })

      # Cast to LINESTRING (ORS may return MULTILINESTRING for complex routes)
      route_sf <- st_cast(route_sf, "LINESTRING")

      # Step 3: Spatial join — accidents within ROUTE_BUFFER_RADIUS of route
      incProgress(0.6, detail = "Finding nearby accidents")
      route_proj      <- st_transform(route_sf, CRS_NYC)
      route_length_km <- as.numeric(st_length(route_proj)) / 1000
      validate(need(route_length_km > 0, "Origin and destination appear to be the same location."))

      route_buffer <- st_buffer(st_union(route_proj), ROUTE_BUFFER_RADIUS)
      nearby_idx   <- st_intersects(route_buffer, accident_sf)[[1]]
      nearby_accidents <- df %>%
        filter(VALID_COORDS) %>%
        slice(nearby_idx)

      incProgress(1.0, detail = "Done")

      list(
        route_sf         = route_sf,
        route_proj       = route_proj,
        route_length_km  = route_length_km,
        nearby_accidents = nearby_accidents,
        origin           = c(lat = origin$lat, lng = origin$lon),
        dest             = c(lat = dest$lat,   lng = dest$lon),
        origin_name      = origin$name,
        dest_name        = dest$name,
        ors_profile      = ors_profile
      )
    })
  })

  ## Show analysis panels ----
  observeEvent(route_analysis(), {
    shinyjs::show("route_results")
  })

  ## Observer 1: Route geometry + density-colored segments ----
  # Triggers on route_analysis() — re-routes only when Analyse Route is clicked
  observeEvent(route_analysis(), {
    res   <- route_analysis()
    proxy <- leafletProxy("route_map") %>%
      clearGroup("route") %>%
      clearGroup("route_markers")

    # Convert nearby accidents to CRS_NYC for spatial ops
    nearby_sf <- if (nrow(res$nearby_accidents) > 0) {
      st_as_sf(res$nearby_accidents,
               coords = c("LONGITUDE", "LATITUDE"), crs = CRS_WGS84) %>%
        st_transform(CRS_NYC)
    } else {
      st_sf(geometry = st_sfc(crs = CRS_NYC))
    }

    # Sample points along route; count accidents within buffer at each point
    n_pts  <- as.integer(max(10L, min(100L,
      round(res$route_length_km * 1000 / ROUTE_SAMPLE_INTERVAL))))
    fracs  <- seq(0, 1, length.out = n_pts)
    pts    <- st_line_sample(res$route_proj, sample = fracs) %>% st_cast("POINT")
    counts <- if (nrow(nearby_sf) > 0)
                lengths(st_intersects(st_buffer(pts, ROUTE_BUFFER_RADIUS), nearby_sf))
              else rep(0L, n_pts)

    # Normalise 0–1 within route; colour yellow → orange → red
    scores     <- counts / max(max(counts), 1L)
    risk_pal   <- colorNumeric(c("#f1c40f", "#e67e22", "#e74c3c"), domain = c(0, 1))
    coords_wgs <- st_coordinates(st_transform(pts, CRS_WGS84))

    for (i in seq_len(n_pts - 1L)) {
      proxy <- proxy %>% addPolylines(
        lng     = coords_wgs[c(i, i + 1L), 1L],
        lat     = coords_wgs[c(i, i + 1L), 2L],
        color   = risk_pal(mean(scores[c(i, i + 1L)])),
        weight  = 6,
        opacity = 0.9,
        group   = "route"
      )
    }

    proxy %>%
      addAwesomeMarkers(
        lng   = res$origin["lng"], lat = res$origin["lat"],
        icon  = awesomeIcons(icon = "play", library = "fa",
                             markerColor = "green", iconColor = "white"),
        popup = paste0("<b>Origin</b><br>", res$origin_name),
        group = "route_markers"
      ) %>%
      addAwesomeMarkers(
        lng   = res$dest["lng"], lat = res$dest["lat"],
        icon  = awesomeIcons(icon = "flag", library = "fa",
                             markerColor = "red", iconColor = "white"),
        popup = paste0("<b>Destination</b><br>", res$dest_name),
        group = "route_markers"
      ) %>%
      fitBounds(
        lng1 = min(res$origin["lng"], res$dest["lng"]) - 0.005,
        lat1 = min(res$origin["lat"], res$dest["lat"]) - 0.005,
        lng2 = max(res$origin["lng"], res$dest["lng"]) + 0.005,
        lat2 = max(res$origin["lat"], res$dest["lat"]) + 0.005
      )
  })

  ## Observer 2: Crash dots (toggle-controlled, mode + time filtered) ----
  # Redraws when filtered data or toggle changes
  observe({
    proxy <- leafletProxy("route_map") %>% clearGroup("crash_markers")

    # Only draw dots when toggle is on and route exists
    req(isTRUE(input$show_crash_dots), route_analysis())
    nearby <- route_analysis()$nearby_accidents
    if (nrow(nearby) == 0) return()

    crash_colors <- unname(CRASH_MAP_COLORS[as.character(nearby$SEVERITY_LABEL)])
    crash_colors[is.na(crash_colors)] <- "#95a5a6"

    proxy %>% addCircleMarkers(
      lng         = nearby$LONGITUDE,
      lat         = nearby$LATITUDE,
      radius      = 3,
      color       = crash_colors,
      fillColor   = crash_colors,
      fillOpacity = 0.5,
      weight      = 0,
      group       = "crash_markers",
      popup       = paste0("<b>", nearby$SEVERITY_LABEL, "</b><br>",
                           nearby$FACTOR_CATEGORY)
    )
  })

  # ── Analysis Panel Outputs ────────────────────────────────────────────────

  ## Route KPIs ----
  output$route_kpis <- renderUI({
    req(route_analysis())
    nearby      <- route_analysis()$nearby_accidents
    res         <- route_analysis()
    n_crashes   <- nrow(nearby)
    validate(need(n_crashes > 0, "No accident records found on this corridor."))

    density_val <- (n_crashes / res$route_length_km) / CITYWIDE_DENSITY[["all"]]
    inj_rate    <- round(mean(nearby$ANY_INJURY, na.rm = TRUE) * 100, 1)
    fatalities  <- sum(nearby$PERSONS_KILLED, na.rm = TRUE)

    density_color <- if (density_val > 2) "#e74c3c" else if (density_val > 1) "#f39c12" else "#27ae60"
    inj_color     <- if (inj_rate > 40)   "#e74c3c" else if (inj_rate > 25)   "#f39c12" else "#27ae60"
    fat_color     <- if (fatalities > 0)  "#e74c3c" else "#27ae60"

    fluidRow(
      column(3,
        tags$div(class = "route-kpi-box",
          tags$div(class = "kpi-value", format(n_crashes, big.mark = ",")),
          tags$div(class = "kpi-label", "Crashes on Corridor"),
          tags$div(class = "kpi-subtext", paste0(round(res$route_length_km, 1), " km route"))
        )
      ),
      column(3,
        tags$div(class = "route-kpi-box",
          tags$div(class = "kpi-value",
                   style = paste0("color:", density_color),
                   paste0(round(density_val, 1), "\u00d7")),
          tags$div(class = "kpi-label", "vs City Average"),
          tags$div(class = "kpi-subtext",
                   paste0(round(n_crashes / res$route_length_km, 0), " crashes/km"))
        )
      ),
      column(3,
        tags$div(class = "route-kpi-box",
          tags$div(class = "kpi-value",
                   style = paste0("color:", inj_color),
                   paste0(inj_rate, "%")),
          tags$div(class = "kpi-label", "Injury Rate"),
          tags$div(class = "kpi-subtext", "of crashes caused injury")
        )
      ),
      column(3,
        tags$div(class = "route-kpi-box",
          tags$div(class = "kpi-value",
                   style = paste0("color:", fat_color),
                   fatalities),
          tags$div(class = "kpi-label", "Fatalities"),
          tags$div(class = "kpi-subtext", "on this corridor in 2020")
        )
      )
    )
  })

  ## Corridor hourly distribution ----
  output$corridor_hourly <- renderPlotly({
    req(route_analysis())
    nearby <- route_analysis()$nearby_accidents
    validate(need(nrow(nearby) > 0, "No accident data for this corridor."))

    hourly <- nearby %>%
      count(HOUR) %>%
      complete(HOUR = 0:23, fill = list(n = 0L))

    plot_ly(hourly, x = ~HOUR, y = ~n, type = "bar",
            marker = list(color = "#e74c3c", line = list(width = 0)),
            hovertemplate = "%{x}:00 \u2014 %{y} crashes<extra></extra>") %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "Hour", tickmode = "linear", dtick = 3)),
        yaxis  = c(PLOTLY_YAXIS, list(title = "Crashes")),
        margin = list(l = 50, r = 10, t = 10, b = 40)
      ) %>%
      apply_dark_theme()
  })

  ## Crashes by Vehicle Type (stacked by severity) ----
  output$corridor_mode_risk <- renderPlotly({
    req(route_analysis())
    nearby <- route_analysis()$nearby_accidents
    validate(need(nrow(nearby) > 0, "No data."))

    vtype_sev <- nearby %>%
      count(PRIMARY_VEHICLE, SEVERITY_LABEL) %>%
      group_by(PRIMARY_VEHICLE) %>%
      mutate(total = sum(n)) %>%
      ungroup() %>%
      filter(total >= 5) %>%
      mutate(
        PRIMARY_VEHICLE = fct_reorder(PRIMARY_VEHICLE, total),
        SEVERITY_LABEL  = factor(SEVERITY_LABEL, levels = SEVERITY_ORDER)
      )

    validate(need(nrow(vtype_sev) > 0, "No vehicle type data."))

    p <- plot_ly()
    for (sev in SEVERITY_ORDER) {
      d <- filter(vtype_sev, SEVERITY_LABEL == sev)
      if (nrow(d) > 0) {
        p <- p %>% add_bars(
          data = d, y = ~PRIMARY_VEHICLE, x = ~n, name = sev,
          orientation = "h",
          marker = list(color = SEVERITY_COLORS[[sev]], line = list(width = 0)),
          hovertemplate = paste0("<b>%{y}</b><br>", sev, ": %{x}<extra></extra>")
        )
      }
    }

    p %>%
      layout(
        barmode = "stack",
        yaxis   = c(PLOTLY_YAXIS, list(title = "")),
        xaxis   = c(PLOTLY_XAXIS, list(title = "")),
        legend  = list(orientation = "h", x = 0.5, xanchor = "center", y = -0.15,
                       bgcolor = "rgba(0,0,0,0)", font = list(size = 10)),
        margin  = list(l = 130, r = 10, t = 10, b = 60)
      ) %>%
      apply_dark_theme()
  })

  ## Corridor top contributing factors ----
  output$corridor_factors <- renderPlotly({
    req(route_analysis())
    nearby <- route_analysis()$nearby_accidents

    top5 <- nearby %>%
      filter(FACTOR_CATEGORY != "Other / Unknown") %>%
      count(FACTOR_CATEGORY, sort = TRUE) %>%
      head(5) %>%
      arrange(n) %>%
      mutate(FACTOR_CATEGORY = factor(FACTOR_CATEGORY, levels = FACTOR_CATEGORY))

    validate(need(nrow(top5) > 0, "No factor data."))

    plot_ly(top5, y = ~FACTOR_CATEGORY, x = ~n,
            type = "bar", orientation = "h",
            marker = list(
              color = FACTOR_COLORS[as.character(top5$FACTOR_CATEGORY)],
              line  = list(width = 0)
            ),
            hovertemplate = "<b>%{y}</b>: %{x}<extra></extra>") %>%
      layout(
        yaxis  = c(PLOTLY_YAXIS, list(title = "")),
        xaxis  = c(PLOTLY_XAXIS, list(title = "Crashes")),
        margin = list(l = 170, r = 10, t = 10, b = 40)
      ) %>%
      apply_dark_theme()
  })

  ## Crashes by Day of Week ----
  output$corridor_dow <- renderPlotly({
    req(route_analysis())
    nearby <- route_analysis()$nearby_accidents
    validate(need(nrow(nearby) > 0, "No data."))

    dow_order <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    dow <- nearby %>%
      count(DAY_OF_WEEK) %>%
      mutate(DAY_OF_WEEK = factor(DAY_OF_WEEK, levels = dow_order))

    bar_colors <- ifelse(dow$DAY_OF_WEEK %in% c("Saturday", "Sunday"), "#e74c3c", "#f39c12")

    plot_ly(dow, x = ~DAY_OF_WEEK, y = ~n, type = "bar",
            marker = list(color = bar_colors, line = list(width = 0)),
            hovertemplate = "<b>%{x}</b>: %{y} crashes<extra></extra>") %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "")),
        yaxis  = c(PLOTLY_YAXIS, list(title = "Crashes")),
        margin = list(l = 50, r = 10, t = 10, b = 30)
      ) %>%
      apply_dark_theme()
  })

  ## Danger zones reactive — hotspot detection along route ----
  danger_zones <- reactive({
    req(route_analysis())
    nearby <- route_analysis()$nearby_accidents
    res    <- route_analysis()
    if (nrow(nearby) < HOTSPOT_MIN_CRASHES) return(NULL)

    # Convert crashes to CRS_NYC
    filt_sf <- st_as_sf(nearby, coords = c("LONGITUDE", "LATITUDE"), crs = CRS_WGS84) %>%
      st_transform(CRS_NYC)

    # Sample points along route at fine intervals
    n_pts <- as.integer(max(10L, round(res$route_length_km * 1000 / HOTSPOT_SAMPLE_STEP)))
    fracs <- seq(0, 1, length.out = n_pts)
    pts   <- st_line_sample(res$route_proj, sample = fracs) %>% st_cast("POINT")

    # Count filtered crashes within HOTSPOT_RADIUS of each point
    counts <- lengths(st_intersects(st_buffer(pts, HOTSPOT_RADIUS), filt_sf))

    # Peak-finding: greedy selection with minimum separation
    zones      <- list()
    coords_utm <- st_coordinates(pts)
    remaining  <- seq_along(counts)

    for (z in 1:3) {
      if (length(remaining) == 0) break
      best_idx <- remaining[which.max(counts[remaining])]
      if (counts[best_idx] < HOTSPOT_MIN_CRASHES) break

      # Get crashes in this zone
      zone_buffer <- st_buffer(pts[best_idx], HOTSPOT_RADIUS)
      zone_hits   <- st_intersects(zone_buffer, filt_sf)[[1]]
      zone_data   <- nearby[zone_hits, ]

      # Zone centroid in WGS84
      centroid_wgs <- st_coordinates(st_transform(pts[best_idx], CRS_WGS84))

      # Most common street name in zone
      zone_street <- zone_data %>%
        filter(!is.na(ON_STREET_NAME), ON_STREET_NAME != "") %>%
        count(ON_STREET_NAME, sort = TRUE) %>%
        slice(1) %>% pull(ON_STREET_NAME)
      zone_street <- if (length(zone_street) == 0) "Unknown area" else zone_street

      # Top contributing factor
      top_factor <- zone_data %>%
        filter(FACTOR_CATEGORY != "Other / Unknown") %>%
        count(FACTOR_CATEGORY, sort = TRUE) %>%
        slice(1) %>% pull(FACTOR_CATEGORY)
      top_factor <- if (length(top_factor) == 0) "Unspecified" else top_factor

      zones[[z]] <- list(
        rank        = z,
        lng         = centroid_wgs[1, "X"],
        lat         = centroid_wgs[1, "Y"],
        crashes     = nrow(zone_data),
        injury_rate = round(mean(zone_data$ANY_INJURY, na.rm = TRUE) * 100, 0),
        fatalities  = sum(zone_data$PERSONS_KILLED, na.rm = TRUE),
        street      = zone_street,
        top_factor  = top_factor
      )

      # Mask out points within HOTSPOT_MIN_SEP of this peak
      dists <- sqrt((coords_utm[remaining, 1] - coords_utm[best_idx, 1])^2 +
                    (coords_utm[remaining, 2] - coords_utm[best_idx, 2])^2)
      remaining <- remaining[dists > HOTSPOT_MIN_SEP]
    }

    if (length(zones) == 0) NULL else zones
  })

  ## Observer 3: Danger zone markers on map ----
  observe({
    proxy <- leafletProxy("route_map") %>% clearGroup("danger_zones")
    zones <- danger_zones()
    if (is.null(zones)) return()

    zone_colors <- c("#e74c3c", "#e67e22", "#f1c40f")

    for (z in zones) {
      proxy <- proxy %>%
        addCircleMarkers(
          lng = z$lng, lat = z$lat, radius = 18,
          color = zone_colors[z$rank], fillColor = zone_colors[z$rank],
          fillOpacity = 0.25, weight = 2, group = "danger_zones",
          popup = paste0(
            "<div style='font-family:Inter,sans-serif;min-width:180px;'>",
            "<b style='font-size:1rem;color:", zone_colors[z$rank], ";'>Zone ", z$rank,
            " \u2014 ", htmltools::htmlEscape(z$street), "</b><br>",
            "<span style='color:#e6edf3;'>", z$crashes, " crashes</span><br>",
            "<span style='color:#f39c12;'>", z$injury_rate, "% injury rate</span>",
            if (z$fatalities > 0) paste0("<br><span style='color:#e74c3c;'>",
                                          z$fatalities, " fatalities</span>") else "",
            "<br><span style='color:#8b949e;'>Top cause: ", htmltools::htmlEscape(z$top_factor), "</span>",
            "</div>"
          )
        ) %>%
        addLabelOnlyMarkers(
          lng = z$lng, lat = z$lat, group = "danger_zones",
          label = as.character(z$rank),
          labelOptions = labelOptions(
            noHide = TRUE, direction = "center", textOnly = TRUE,
            style = list("font-size" = "14px", "font-weight" = "700",
                         "color" = "white")
          )
        )
    }
  })

  ## Danger zone cards ----
  output$danger_zone_cards <- renderUI({
    zones <- danger_zones()
    if (is.null(zones)) {
      return(tags$div(class = "low-data-banner",
        icon("shield-halved"),
        tags$span("Not enough data to identify danger zones for these filters.")
      ))
    }

    zone_colors <- c("#e74c3c", "#e67e22", "#f1c40f")

    cards <- lapply(zones, function(z) {
      column(4,
        tags$div(
          class = "danger-zone-card",
          style = paste0("border-left:3px solid ", zone_colors[z$rank], ";cursor:pointer;"),
          onclick = sprintf(
            "Shiny.setInputValue('flyto_zone', {lng: %f, lat: %f, rank: %d}, {priority:'event'});",
            z$lng, z$lat, z$rank
          ),
          tags$div(class = "zone-header",
            tags$span(class = "zone-badge",
                      style = paste0("background:", zone_colors[z$rank]),
                      z$rank),
            tags$span(class = "zone-street", z$street)
          ),
          tags$div(class = "zone-stats",
            tags$span(class = "zone-stat",
              tags$b(z$crashes), " crashes"),
            tags$span(class = "zone-stat",
              tags$b(paste0(z$injury_rate, "%")), " injured"),
            if (z$fatalities > 0)
              tags$span(class = "zone-stat zone-fatal",
                tags$b(z$fatalities), " fatal")
          ),
          tags$div(class = "zone-factor",
            tags$span(style = "color:var(--text-muted);", "Top cause: "),
            tags$span(style = "color:var(--text-secondary);", z$top_factor)
          )
        )
      )
    })

    do.call(fluidRow, cards)
  })

  ## FlyTo observer (danger zone card click) ----
  observeEvent(input$flyto_zone, {
    z <- input$flyto_zone
    leafletProxy("route_map") %>%
      flyTo(lng = z$lng, lat = z$lat, zoom = 16)
  })

} # end server
