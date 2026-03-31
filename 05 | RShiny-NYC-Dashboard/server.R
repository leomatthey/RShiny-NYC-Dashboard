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
      style = "font-size: 0.82rem; color: #e6edf3;",
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

  ## Parse lat/lon from selectize geocode value ----
  # Value format from autocomplete: "lat|lon|display_name"
  # Falls back to tidygeocoder for plain text input
  parse_address_value <- function(val) {
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

      # Step 1: Resolve coordinates (parse autocomplete value or geocode plain text)
      incProgress(0.1, detail = "Resolving addresses")
      origin <- parse_address_value(trimws(input$route_origin))
      dest   <- parse_address_value(trimws(input$route_dest))

      validate(need(
        !is.na(origin$lat) & !is.na(dest$lat),
        "Could not geocode one or both addresses. Try selecting from the dropdown suggestions."
      ))

      origin_coords <- c(origin$lon, origin$lat)
      dest_coords   <- c(dest$lon,   dest$lat)

      # Step 2: Route via OSRM (fallback to straight line)
      incProgress(0.2, detail = "Computing route")
      used_fallback <- FALSE
      route_sf <- tryCatch({
        osrm::osrmRoute(
          src      = c(lon = origin_coords[1], lat = origin_coords[2]),
          dst      = c(lon = dest_coords[1],   lat = dest_coords[2]),
          overview = "full"
        )
      }, error = function(e) {
        used_fallback <<- TRUE
        line <- st_sfc(
          st_linestring(rbind(origin_coords, dest_coords)),
          crs = CRS_WGS84
        )
        st_sf(geometry = line, duration = NA_real_, distance = NA_real_)
      })

      if (used_fallback) {
        showNotification("Route API unavailable — using straight-line approximation.",
                         type = "warning", duration = 6)
      }

      # Step 3: Sample points along route
      incProgress(0.3, detail = "Sampling route points")
      route_proj    <- st_transform(route_sf, CRS_NYC)
      route_length  <- as.numeric(st_length(route_proj))

      validate(need(route_length > 0,
                    "Origin and destination appear to be the same location."))

      n_samples       <- as.integer(max(10L, min(500L, round(route_length / ROUTE_SAMPLE_INTERVAL))))
      sample_fractions <- seq(0, 1, length.out = n_samples)

      sample_pts_proj <- st_line_sample(route_proj, sample = sample_fractions) %>%
        st_cast("POINT")
      sample_pts_wgs  <- st_transform(sample_pts_proj, CRS_WGS84)
      coords_mat      <- st_coordinates(sample_pts_wgs)

      # Step 4: Borough assignment (nearest-neighbor)
      incProgress(0.4, detail = "Assigning boroughs")
      sample_sf   <- st_as_sf(
        data.frame(LONGITUDE = coords_mat[, 1], LATITUDE = coords_mat[, 2]),
        coords = c("LONGITUDE", "LATITUDE"), crs = CRS_WGS84
      )
      nearest_idx <- st_nearest_feature(sample_sf, borough_ref_sf)
      boroughs    <- borough_ref_sf$BOROUGH[nearest_idx]

      # Step 5: Build prediction data frame
      incProgress(0.5, detail = "Building feature matrix")
      hour_val  <- as.integer(input$route_hour)
      dow_val   <- as.integer(input$route_day)
      month_val <- as.integer(input$route_month)
      is_weekend <- dow_val %in% c(6L, 7L)
      is_rush    <- (hour_val >= 7L & hour_val <= 9L) | (hour_val >= 16L & hour_val <= 18L)
      time_period <- dplyr::case_when(
        hour_val >= 6L  & hour_val < 12L ~ "Morning",
        hour_val >= 12L & hour_val < 17L ~ "Afternoon",
        hour_val >= 17L & hour_val < 21L ~ "Evening",
        TRUE ~ "Night"
      )

      pred_df <- data.frame(
        HOUR            = rep(hour_val, n_samples),
        DAY_OF_WEEK_NUM = rep(dow_val, n_samples),
        MONTH_NUM       = rep(month_val, n_samples),
        IS_WEEKEND      = factor(rep(as.character(is_weekend), n_samples),
                                 levels = c("FALSE", "TRUE")),
        IS_RUSH_HOUR    = factor(rep(as.character(is_rush), n_samples),
                                 levels = c("FALSE", "TRUE")),
        TIME_PERIOD     = factor(rep(time_period, n_samples),
                                 levels = TIME_PERIOD_LEVELS),
        BOROUGH         = factor(as.character(boroughs),
                                 levels = levels(borough_ref_sf$BOROUGH)),
        PRIMARY_VEHICLE = factor(rep(input$route_vehicle, n_samples),
                                 levels = VEHICLE_CHOICES),
        LATITUDE        = coords_mat[, 2],
        LONGITUDE       = coords_mat[, 1]
      )

      # Step 6: Model predictions
      incProgress(0.6, detail = "Running GBM model")
      model_probs <- predict(final_model, newdata = pred_df, type = "prob")[, "Yes"]

      # Step 7: Historical density scoring
      incProgress(0.7, detail = "Computing accident density")
      sample_pts_buffered <- st_buffer(sample_pts_proj, ROUTE_BUFFER_RADIUS)
      counts_per_segment  <- lengths(st_intersects(sample_pts_buffered, accident_sf))
      density_scores      <- pmin(counts_per_segment / DENSITY_CAP, 1.0)

      # Step 8: Combined risk
      incProgress(0.8, detail = "Computing risk scores")
      combined_scores <- WEIGHT_DENSITY * density_scores + WEIGHT_MODEL * model_probs
      overall_risk    <- mean(combined_scores) * 100

      # Step 9: Route threats
      incProgress(0.9, detail = "Identifying threats")
      route_buffered <- st_buffer(route_proj, ROUTE_BUFFER_RADIUS)
      nearby_idx     <- st_intersects(route_buffered, accident_sf)[[1]]

      nearby_accidents <- df %>%
        filter(VALID_COORDS) %>%
        slice(nearby_idx)

      top_causes <- nearby_accidents %>%
        filter(FACTOR_CATEGORY != "Other / Unknown") %>%
        count(FACTOR_CATEGORY, sort = TRUE) %>%
        head(5)

      hotspot_streets <- nearby_accidents %>%
        filter(!is.na(ON_STREET_NAME), ON_STREET_NAME != "") %>%
        count(ON_STREET_NAME, sort = TRUE) %>%
        head(5)

      n_nearby   <- nrow(nearby_accidents)
      n_injuries <- sum(nearby_accidents$PERSONS_INJURED, na.rm = TRUE)
      n_fatal    <- sum(nearby_accidents$PERSONS_KILLED,  na.rm = TRUE)

      incProgress(1.0, detail = "Done")

      list(
        route_sf         = route_sf,
        coords           = coords_mat,
        combined_scores  = combined_scores,
        nearby_accidents = nearby_accidents,
        origin_name      = origin$name,
        dest_name        = dest$name,
        model_probs     = model_probs,
        density_scores  = density_scores,
        overall_risk    = overall_risk,
        origin          = c(lat = origin$lat, lng = origin$lon),
        dest            = c(lat = dest$lat,   lng = dest$lon),
        n_nearby        = n_nearby,
        n_injuries      = n_injuries,
        n_fatal         = n_fatal,
        top_causes      = top_causes,
        hotspot_streets = hotspot_streets,
        route_duration  = route_sf$duration,
        route_distance  = route_sf$distance
      )
    })
  })

  ## Show results panel on analysis ----
  observeEvent(route_analysis(), {
    shinyjs::show("route_results")
  })

  ## Update route map with colored segments ----
  observeEvent(route_analysis(), {
    res <- route_analysis()

    risk_pal <- colorNumeric(
      palette = c("#27ae60", "#f39c12", "#e74c3c"),
      domain  = c(0, 1)
    )

    coords <- res$coords
    scores <- res$combined_scores

    proxy <- leafletProxy("route_map") %>%
      clearGroup("route_segments") %>%
      clearGroup("route_markers")

    # Draw colored polyline segments
    for (i in seq_len(nrow(coords) - 1)) {
      seg       <- rbind(coords[i, ], coords[i + 1, ])
      seg_score <- mean(scores[c(i, i + 1)])

      proxy <- proxy %>%
        addPolylines(
          lng = seg[, 1], lat = seg[, 2],
          color   = risk_pal(seg_score),
          weight  = 5,
          opacity = 0.9,
          group   = "route_segments"
        )
    }

    # Origin / destination markers
    proxy %>%
      addAwesomeMarkers(
        lng   = res$origin["lng"], lat = res$origin["lat"],
        icon  = makeAwesomeIcon(icon = "play", markerColor = "green", library = "fa"),
        group = "route_markers",
        popup = paste0("<b>Origin</b><br>", res$origin_name)
      ) %>%
      addAwesomeMarkers(
        lng   = res$dest["lng"], lat = res$dest["lat"],
        icon  = makeAwesomeIcon(icon = "flag-checkered", markerColor = "red", library = "fa"),
        group = "route_markers",
        popup = paste0("<b>Destination</b><br>", res$dest_name)
      ) %>%
      fitBounds(
        lng1 = min(coords[, 1]) - 0.005, lat1 = min(coords[, 2]) - 0.005,
        lng2 = max(coords[, 1]) + 0.005, lat2 = max(coords[, 2]) + 0.005
      )

    # Add nearby historical crash circles (colored by severity)
    nearby <- res$nearby_accidents
    if (nrow(nearby) > 0) {
      crash_colors <- SEVERITY_COLORS[as.character(nearby$SEVERITY_LABEL)]
      crash_colors[is.na(crash_colors)] <- "#5d6d7e"

      leafletProxy("route_map") %>%
        addCircleMarkers(
          lng         = nearby$LONGITUDE,
          lat         = nearby$LATITUDE,
          radius      = 4,
          color       = crash_colors,
          fillColor   = crash_colors,
          fillOpacity = 0.55,
          weight      = 0,
          group       = "crash_markers",
          popup       = paste0(
            "<b>", nearby$SEVERITY_LABEL, "</b><br>",
            nearby$FACTOR_CATEGORY
          )
        )
    }
  })

  ## Risk gauge ----
  output$risk_gauge <- renderPlotly({
    res      <- route_analysis()
    risk_val <- round(res$overall_risk, 1)
    bar_color <- if (risk_val < RISK_LOW_THRESHOLD) RISK_COLORS_MAP["LOW"]
                 else if (risk_val < RISK_HIGH_THRESHOLD) RISK_COLORS_MAP["MODERATE"]
                 else RISK_COLORS_MAP["HIGH"]

    plot_ly(
      type  = "indicator",
      mode  = "gauge+number",
      value = risk_val,
      number = list(suffix = "%", font = list(size = 28, color = "#e6edf3")),
      gauge  = list(
        axis = list(range = list(0, 100),
                    tickcolor = "#8b949e", tickfont = list(color = "#8b949e")),
        bar       = list(color = bar_color),
        bgcolor   = "#21262d",
        bordercolor = "#30363d",
        steps = list(
          list(range = c(0, RISK_LOW_THRESHOLD),  color = "rgba(39,174,96,0.15)"),
          list(range = c(RISK_LOW_THRESHOLD, RISK_HIGH_THRESHOLD), color = "rgba(243,156,18,0.15)"),
          list(range = c(RISK_HIGH_THRESHOLD, 100), color = "rgba(231,76,60,0.15)")
        )
      )
    ) %>%
      layout(
        paper_bgcolor = PLOTLY_LAYOUT$paper_bgcolor,
        font   = PLOTLY_LAYOUT$font,
        margin = list(l = 20, r = 20, t = 40, b = 0)
      ) %>%
      config(displayModeBar = FALSE)
  })

  ## Risk stats panel ----
  output$risk_stats <- renderUI({
    res      <- route_analysis()
    risk_val <- round(res$overall_risk, 1)

    risk_label <- if (risk_val < RISK_LOW_THRESHOLD) "LOW RISK"
                  else if (risk_val < RISK_HIGH_THRESHOLD) "MODERATE RISK"
                  else "HIGH RISK"
    risk_class <- if (risk_val < RISK_LOW_THRESHOLD) "risk-low"
                  else if (risk_val < RISK_HIGH_THRESHOLD) "risk-moderate"
                  else "risk-high"

    dist_text <- if (!is.na(res$route_distance)) paste0(round(res$route_distance, 1), " km") else "N/A"

    tags$div(class = "risk-stats-panel",
      tags$div(class = paste("risk-badge", risk_class), risk_label),
      tags$div(class = "model-method-note",
        icon("circle-info"), " ",
        "Risk = 40% crash frequency\u00a0+\u00a060% GBM injury probability, sampled every 200\u00a0m along route"
      ),
      tags$div(class = "risk-stat-row",
        tags$span(class = "risk-stat-label", "Distance"),
        tags$span(class = "risk-stat-value", dist_text)
      ),
      tags$div(class = "risk-stat-row",
        tags$span(class = "risk-stat-label", "Historical Accidents Nearby"),
        tags$span(class = "risk-stat-value", format(res$n_nearby, big.mark = ","))
      ),
      tags$div(class = "risk-stat-row",
        tags$span(class = "risk-stat-label", "Injuries on This Corridor"),
        tags$span(class = "risk-stat-value", style = "color: #f39c12;",
                  format(res$n_injuries, big.mark = ","))
      ),
      tags$div(class = "risk-stat-row",
        tags$span(class = "risk-stat-label", "Fatalities on This Corridor"),
        tags$span(class = "risk-stat-value", style = "color: #e74c3c;",
                  format(res$n_fatal, big.mark = ","))
      )
    )
  })

  ## Route threats panel ----
  output$route_threats <- renderUI({
    res <- route_analysis()

    # Hotspot streets
    streets_html <- if (nrow(res$hotspot_streets) > 0) {
      items <- paste0(
        "<tr><td style='color:#e6edf3;padding:4px 8px;'>", res$hotspot_streets$ON_STREET_NAME,
        "</td><td style='text-align:right;color:#e74c3c;font-weight:600;padding:4px 8px;'>",
        res$hotspot_streets$n, " crashes</td></tr>"
      )
      paste0("<table style='width:100%;font-size:0.82rem;'>", paste(items, collapse = ""), "</table>")
    } else {
      "<p style='color:#8b949e;'>No known hotspots on this route.</p>"
    }

    # Top causes
    causes_html <- if (nrow(res$top_causes) > 0) {
      items <- paste0(
        "<tr><td style='color:#e6edf3;padding:4px 8px;'>",
        "<span style='display:inline-block;width:8px;height:8px;border-radius:50%;background:",
        FACTOR_COLORS[as.character(res$top_causes$FACTOR_CATEGORY)],
        ";margin-right:6px;'></span>",
        res$top_causes$FACTOR_CATEGORY,
        "</td><td style='text-align:right;color:#8b949e;padding:4px 8px;'>",
        res$top_causes$n, "</td></tr>"
      )
      paste0("<table style='width:100%;font-size:0.82rem;'>", paste(items, collapse = ""), "</table>")
    } else {
      "<p style='color:#8b949e;'>Insufficient data.</p>"
    }

    # Advice card
    advice <- if (res$overall_risk >= RISK_HIGH_THRESHOLD) {
      "This route passes through high-risk corridors. Consider travelling during off-peak hours or choosing an alternative route."
    } else if (res$overall_risk >= RISK_LOW_THRESHOLD) {
      "Moderate risk detected on parts of this route. Stay alert, especially at the highlighted intersections."
    } else {
      "This route has relatively low historical accident density. Standard caution applies."
    }

    tags$div(
      fluidRow(
        column(6,
          tags$div(class = "threat-section",
            tags$h5(class = "threat-title", icon("map-pin"), " Hotspot Streets"),
            HTML(streets_html)
          )
        ),
        column(6,
          tags$div(class = "threat-section",
            tags$h5(class = "threat-title", icon("exclamation-triangle"), " Top Causes"),
            HTML(causes_html)
          )
        )
      ),
      tags$div(class = "advice-card",
        tags$div(class = "advice-icon", icon("lightbulb")),
        tags$p(advice)
      )
    )
  })

  # ── Model Performance (static, no route dependency) ──────────────────────

  ## ROC Curve ----
  output$model_roc <- renderPlotly({
    roc_coords <- pROC::coords(roc_obj, "all", ret = c("specificity", "sensitivity"))
    fpr <- 1 - roc_coords$specificity
    tpr <- roc_coords$sensitivity
    auc_val <- round(as.numeric(pROC::auc(roc_obj)), 3)

    plot_ly() %>%
      add_trace(x = c(0, 1), y = c(0, 1), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "#30363d"),
                name = "Random (AUC = 0.50)", showlegend = TRUE) %>%
      add_trace(x = fpr, y = tpr, type = "scatter", mode = "lines",
                line = list(color = "#e74c3c", width = 2.5),
                name = paste0("GBM (AUC = ", auc_val, ")"),
                hovertemplate = "FPR: %{x:.3f}<br>TPR: %{y:.3f}<extra></extra>") %>%
      layout(
        xaxis = c(PLOTLY_XAXIS, list(title = "False Positive Rate", range = c(0, 1))),
        yaxis = c(PLOTLY_YAXIS, list(title = "True Positive Rate",  range = c(0, 1))),
        legend = list(x = 0.55, y = 0.2, bgcolor = "rgba(0,0,0,0)"),
        margin = list(l = 50, r = 20, t = 10, b = 50),
        annotations = list(
          list(text = paste0("<b>AUC = ", auc_val, "</b>"),
               x = 0.75, y = 0.15, showarrow = FALSE,
               font = list(size = 16, color = "#e74c3c"),
               bgcolor = "#161b22", bordercolor = "#e74c3c", borderwidth = 1)
        )
      ) %>%
      apply_dark_theme()
  })

  ## Confusion Matrix (heatmap) ----
  output$model_conf_mat <- renderPlotly({
    cm_table <- as.matrix(conf_mat$table)
    z_mat    <- t(cm_table)    # rows = Actual, cols = Predicted
    labels   <- c("No Injury", "Injury")

    text_mat <- matrix(format(as.vector(z_mat), big.mark = ","), nrow = 2)

    acc  <- round(conf_mat$overall["Accuracy"]     * 100, 1)
    sens <- round(conf_mat$byClass["Sensitivity"]  * 100, 1)
    spec <- round(conf_mat$byClass["Specificity"]  * 100, 1)

    plot_ly(
      z     = z_mat,
      x     = labels,
      y     = labels,
      type  = "heatmap",
      colorscale   = list(c(0, "#161b22"), c(1, "#e74c3c")),
      text         = text_mat,
      texttemplate = "%{text}",
      textfont     = list(size = 20, color = "white"),
      showscale    = FALSE,
      hovertemplate = "Actual: %{y}<br>Predicted: %{x}<br>Count: %{text}<extra></extra>"
    ) %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "Predicted")),
        yaxis  = c(PLOTLY_YAXIS, list(title = "Actual", autorange = "reversed")),
        margin = list(l = 80, r = 20, t = 40, b = 60),
        annotations = list(
          list(text = paste0("Accuracy: ", acc, "% &nbsp; Sensitivity: ", sens,
                             "% &nbsp; Specificity: ", spec, "%"),
               x = 0.5, y = 1.1, xref = "paper", yref = "paper",
               showarrow = FALSE, font = list(size = 11, color = "#8b949e"))
        )
      ) %>%
      apply_dark_theme()
  })

  ## Variable Importance ----
  output$model_var_imp <- renderPlotly({
    imp_df <- var_imp$importance %>%
      tibble::rownames_to_column("Feature") %>%
      arrange(Overall) %>%
      mutate(Feature = factor(Feature, levels = Feature))

    plot_ly(imp_df, y = ~Feature, x = ~Overall, type = "bar", orientation = "h",
            marker = list(
              color = ~Overall,
              colorscale = list(c(0, "#21262d"), c(0.5, "#3498db"), c(1, "#e74c3c")),
              line = list(width = 0)
            ),
            hovertemplate = "<b>%{y}</b><br>Importance: %{x:.1f}%<extra></extra>") %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "Relative Importance (%)")),
        yaxis  = c(PLOTLY_YAXIS, list(title = "")),
        margin = list(l = 140, r = 20, t = 10, b = 50)
      ) %>%
      apply_dark_theme()
  })

  ## Calibration Plot ----
  output$model_calibration <- renderPlotly({
    plot_ly() %>%
      add_trace(x = c(0, 1), y = c(0, 1), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "#30363d"),
                name = "Perfect Calibration") %>%
      add_trace(data = cal_df, x = ~mean_predicted, y = ~mean_observed,
                type = "scatter", mode = "lines+markers",
                line   = list(color = "#27ae60", width = 2.5),
                marker = list(size = 8, color = "#27ae60"),
                name = "GBM Model",
                text = ~paste0("n = ", format(n, big.mark = ",")),
                hovertemplate = "Predicted: %{x:.3f}<br>Observed: %{y:.3f}<br>%{text}<extra></extra>") %>%
      layout(
        xaxis  = c(PLOTLY_XAXIS, list(title = "Mean Predicted Probability", range = c(0, 1))),
        yaxis  = c(PLOTLY_YAXIS, list(title = "Fraction of Positives",      range = c(0, 1))),
        legend = list(x = 0.05, y = 0.95, bgcolor = "rgba(0,0,0,0)"),
        margin = list(l = 50, r = 20, t = 10, b = 50)
      ) %>%
      apply_dark_theme()
  })

} # end server
