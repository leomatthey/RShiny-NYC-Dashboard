# PLAN.md — NYC Accidents 2020 R Shiny Dashboard

> **How to use this document:**
>
> 1. **Every session start:** Read this file alongside `CLAUDE.md`. Together they give full context. `CLAUDE.md` owns rules/conventions. This file owns architecture, specs, and progress.
> 2. **After completing a phase:** Move the finished phase to "Completed Phases" with a brief summary of what was built plus any key metrics or gotchas the next session should know. Promote the next upcoming phase to "Current Phase" and expand its detail. Keep upcoming phases as overviews.
> 3. **Never duplicate CLAUDE.md content here.** If you need a convention or rule, reference CLAUDE.md.

---

## Architecture

```
05 | RShiny-NYC-Dashboard/
├── app.R                    # Entry point: sources global.R + ui.R + server.R
├── global.R                 # Packages, data loading, shared constants
├── ui.R                     # shinydashboard UI (sidebar + 5 tabs)
├── server.R                 # Reactive logic, charts, route prediction
├── data_processing.R        # Offline: CSV -> DATA/processed_data.RData
├── model_comparison.R       # Offline: compare algorithms (justify choice)
├── model_training.R         # Offline: train final model -> append to RData
├── DATA/
│   └── processed_data.RData # Preprocessed data + model artifacts
├── www/
│   ├── custom.css           # Dark theme
│   └── custom.js            # Tab animations, crash count badge
└── SETUP/
    ├── requirements.R
    ├── dockerfile
    ├── docker-compose.yaml
    └── entrypoint.sh
```

**Source data:** `../03 | DATA/NYC Accidents 2020.csv` (74,881 rows, 29 columns)

### Packages

```r
shiny, shinydashboard, shinyWidgets, shinyjs          # Core
dplyr, tidyr, lubridate, stringr, forcats, readr      # Data
sf, osrm, tidygeocoder                                # Spatial (route feature)
plotly, leaflet, leaflet.extras, viridis, scales, DT  # Visualization
caret, gbm, pROC, randomForest, rpart                  # Model (randomForest/rpart for comparison only)
glue                                                  # Utility
```

---

## Processed Data Reference

`DATA/processed_data.RData` contains `df` (74,881 x 48), 10 summary tables, and 6 model artifacts.

### Key characteristics

| Metric | Value |
|--------|-------|
| Valid GPS coordinates | 92.0% |
| Known borough | 65.6% (34% missing in source) |
| ANY_INJURY rate (model target) | 27.4% |
| Factor identified (non-Unspecified) | 73.6% |

### Engineered columns on df

| Group | Columns |
|-------|---------|
| Temporal | HOUR, DAY_OF_WEEK, DAY_OF_WEEK_NUM, MONTH, MONTH_NUM, IS_WEEKEND, IS_RUSH_HOUR, TIME_PERIOD |
| Severity | SEVERITY_LABEL (PDO / Injury / Severe Injury / Fatal), ANY_INJURY |
| Victim flags | PED_INVOLVED, CYC_INVOLVED, MOT_INVOLVED |
| Causes | PRIMARY_FACTOR (raw string), FACTOR_CATEGORY (10 levels) |
| Vehicles | PRIMARY_VEHICLE (7 levels), N_VEHICLES |
| Geographic | BOROUGH (6-level factor incl. Unknown), LATITUDE, LONGITUDE, VALID_COORDS |

### Pre-aggregated tables

| Table | Shape | Used in |
|-------|-------|---------|
| heatmap_counts | HOUR x DAY_OF_WEEK_NUM -> crashes, injured | Tab 3 |
| borough_summary | BOROUGH -> crashes, injured, killed, pct_injury | Tab 1 |
| borough_severity | BOROUGH x SEVERITY_LABEL -> n, pct | Tab 1 |
| hourly_summary | HOUR -> crashes, injured, pct_injury | Tab 1 |
| borough_heatmap | HOUR x BOROUGH -> crashes | Tab 3 |
| top_factors | Top 20 PRIMARY_FACTOR -> crashes, pct_injury | Tab 4 |
| vehicle_breakdown | PRIMARY_VEHICLE x SEVERITY_LABEL -> n, pct | Tab 4 |
| monthly_factor_trends | MONTH x FACTOR_CATEGORY -> crashes | Tab 4 |
| vehicle_factor_breakdown | PRIMARY_VEHICLE x FACTOR_CATEGORY -> n, pct | Tab 4 |
| factor_severity | FACTOR_CATEGORY x SEVERITY_LABEL -> n, pct | Tab 4 |

### Model artifacts

| Object | What it is | Used in |
|--------|-----------|---------|
| final_model | Trained caret GBM model object | Tab 5 predictions |
| conf_mat | confusionMatrix() on 20% test set | Tab 5 model performance |
| roc_obj | pROC::roc() object (AUC = 0.635) | Tab 5 ROC curve |
| var_imp | varImp() result | Tab 5 feature importance |
| cal_df | 10-bin calibration data (predicted vs observed) | Tab 5 calibration plot |
| test_df | Held-out test data (9,828 rows, 10 cols) | Tab 5 reproducibility |

---

## Completed Phases

### Phase 1: Data Preprocessing -- DONE

**File:** `data_processing.R` (362 lines)
**Output:** `DATA/processed_data.RData` (df + 10 tables)

Built: column normalisation, temporal extraction, geographic cleaning, severity labels (4-level + binary target), victim-type flags, contributing factor consolidation (pivot 5 cols -> primary -> 9 categories), vehicle type consolidation (pivot 5 cols -> primary -> 7 categories), 10 pre-aggregated summary tables.

Factor mapping is comprehensive -- only 7 records ("Vehicle Vandalism") remain uncategorised outside of "Unspecified".

### Phase 2: Model Pipeline -- DONE

**Files:** `model_comparison.R` (127 lines), `model_training.R` (125 lines)
**Output:** `DATA/model_comparison_dotplot.png`, `DATA/model_comparison_results.txt`, 6 new artifacts in `DATA/processed_data.RData`

Built: 4-algorithm comparison (GLM, Decision Tree, Random Forest, GBM) via 5-fold CV on 38,156 training rows (filtered to known borough + valid coordinates). GBM won (Test AUC = 0.635 vs GLM 0.622, RPART 0.610, RF 0.610). Final GBM trained with tuned hyperparameters (n.trees=200, interaction.depth=3, shrinkage=0.1).

**Features (10):** HOUR, DAY_OF_WEEK_NUM, MONTH_NUM, IS_WEEKEND, IS_RUSH_HOUR, TIME_PERIOD, BOROUGH, PRIMARY_VEHICLE, LATITUDE, LONGITUDE. Only pre-accident-knowable features included (N_VEHICLES and FACTOR_CATEGORY excluded as post-hoc).

**Model artifacts in processed_data.RData:** `final_model` (caret GBM object), `conf_mat`, `roc_obj` (AUC=0.635), `var_imp`, `cal_df` (10 bins), `test_df` (9,538 rows).

**Key metrics:** Accuracy 75.5%, AUC 0.635. Modest AUC is expected — injury severity is inherently hard to predict from pre-crash features alone. The model provides meaningful relative risk ranking (temporal + spatial patterns) rather than precise absolute predictions. Top features: Bicycle/E-Bike type, MONTH_NUM, LONGITUDE, LATITUDE, HOUR.

**Two-stage risk approach in Tab 5:** (1) Historical spatial density from accident data identifies dangerous streets/intersections. (2) The model adds temporal/contextual risk adjustment (time of day, vehicle type, location). Together they produce location-specific + context-aware risk scores.

**Note for Phase 4:** Use `predict(final_model, newdata, type = "prob")` in the app.

### Phase 3: App Foundation + Tabs 1-4 -- DONE

**Files:** `app.R` (9 lines), `global.R` (80 lines), `ui.R` (~220 lines), `server.R` (~650 lines), `www/custom.css` (~500 lines), `www/custom.js` (43 lines)

Built: Full shinydashboard app with dark theme (CSS custom properties), 5 sidebar filters (hour range, borough picker, severity picker, month range, commuter type) with reset button and JS-updated crash count badge. All filters apply globally via `filtered_df` reactive with NULL guards. Shared constants (color palettes, plotly defaults) live in `global.R`.

**20 total outputs** across 4 tabs, all filter-responsive. Tab 5 has placeholder UI for Phase 4. Inter font loaded from Google Fonts. Plotly dark theme helper (`apply_dark_theme`) standardises all chart styling.

**Architecture note:** `app.R` sources `global.R` → `ui.R` → `server.R`. Constants must be in `global.R` (not `ui.R`) so both UI and server can access them.

### Phase 3b: Dashboard Refinement -- DONE

All 11 items completed across 5 batches:

1. **CSS fixes:** Sidebar scroll (`overflow-y: auto`), box titles enlarged (`1.15rem`), KPI icons resized (`3rem`), KPI boxes `min-height: 95px` with proper inner padding.
2. **Data range:** `MAX_MONTH` constant in `global.R`, month slider and `complete()` calls use it — no more empty Sep-Dec bars.
3. **Chart fixes:** Borough chart redesigned as horizontal grouped bars (crashes/injured/killed). Victim donut uses "Vehicle Occupants" label with `textinfo="none"`. Top factors uses `customdata` instead of `text` for clean bars.
4. **Map fixes:** Heatmap guard (`req(input$crash_map_bounds)`), tuned gradient (`c("transparent", "#fed976", "#fd8d3c", "#e31a1c", "#bd0026")`, radius=14, blur=15, max=1). Dangerous streets DT with `selection="single"`, formatted columns, Unspecified fallback. FlyTo observer with hotspot coordinates (densest crash cluster via rounded lat/lng mode), `addAwesomeMarkers` with popup, group-based clearing to prevent cross-observer interference.
5. **Layout:** Causes tab reordered (Top Factors → Factor Severity + Trends → Vehicle × Severity + Factor by Vehicle). Borough Vulnerability moved to Overview tab Row 4. Reset button sized via CSS (`width: calc(100% - 24px)`, `margin: 12px`, `height: 42px`) to match sidebar `.form-group` content area — removed Shiny's inline `width:100%` to prevent specificity conflict.

---

## Current Phase: Phase 4 — Tab 5: Route Risk Predictor

| Position | Content |
|----------|---------|
| Row 1 | Origin/destination text inputs + vehicle/hour/day selectors + "Analyse Route" button + leafletOutput with route polyline colored green->amber->red by accident density |
| Row 2L | Risk score gauge (0-100%) + risk label (LOW / MODERATE / HIGH) + key stats |
| Row 2R | "Top Threats" -- hotspot intersections, top causes on route, advice card |
| Row 3 | Model performance tabsetPanel: ROC curve, confusion matrix (DT), variable importance (plotly), calibration plot |

Server: `eventReactive(input$analyse_route_btn)` -> geocode (`tidygeocoder`) -> route (`osrm::osrmRoute()`, OSRM demo server) -> `sf::st_buffer(75m)` -> spatial join accidents -> apply final_model -> aggregate risk per segment -> color route

### Phase 5: Polish + Deploy

- Reset button wiring, loading spinners, tooltip text
- README.md
- SETUP/ files (requirements.R, dockerfile, docker-compose.yaml, entrypoint.sh)
- Deploy to AWS EC2 per `02 | Instructions/shiny_app_setup.txt`
