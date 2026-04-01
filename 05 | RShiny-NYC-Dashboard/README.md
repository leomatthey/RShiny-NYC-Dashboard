# NYC Traffic Accidents 2020 Dashboard

An interactive R Shiny dashboard analysing 74,881 traffic accidents across New York City's five boroughs in 2020. Built as a group project for the Data Analytics with R course at ESADE (MiBA, Term 2).

**Live App:** [http://15.188.143.227:3838/nyc-dashboard/]

---

## Tabs

### 1. Overview
Key metrics at a glance: total crashes, injuries, fatalities, and injury rate. Borough comparisons, victim type breakdowns, hourly crash distributions, severity patterns, and pedestrian/cyclist vulnerability analysis.

### 2. Interactive Map
Leaflet heatmap and marker views of all geocoded crashes. Includes map controls for toggling between heatmap and individual markers, summary statistics, and a searchable table of the most dangerous streets.

### 3. Time Analysis
Temporal deep dive: hour-by-day-of-week heatmap, day-of-week patterns, victim type by time of day, monthly crash volume trends, and hour-by-borough heatmaps.

### 4. Causes & Vehicles
Contributing factor analysis: top factors ranked by frequency, factor severity profiles, category trends over time, vehicle type severity breakdowns, and factor composition by vehicle type.

### 5. Route Risk
Enter an origin and destination to analyse historical crash data along your route. Features density-coloured route visualisation (yellow to red), automated danger zone detection with hotspot clustering, corridor KPIs, and breakdowns by day of week, hour, vehicle type, and contributing factors.

---

## Project Structure

```
05 | RShiny-NYC-Dashboard/
├── app.R                    # Entry point: sources global.R, ui.R, server.R
├── global.R                 # Packages, data loading, shared constants
├── ui.R                     # shinydashboard UI (sidebar + 5 tabs)
├── server.R                 # Reactive logic, charts, route risk analysis
├── data_processing.R        # Offline: CSV -> DATA/processed_data.RData
├── model_comparison.R       # Offline: 4-algorithm comparison (GLM, RPART, RF, GBM)
├── model_training.R         # Offline: final GBM model training + evaluation
├── MODEL_DOCUMENTATION.md   # Model process, results, and design decision
├── DATA/
│   ├── NYC_Accidents_2020.csv         # Source data (74,881 rows)
│   ├── processed_data.RData           # Preprocessed data + model artifacts
│   ├── model_comparison_results.txt
│   └── model_comparison_dotplot.png
├── SETUP/
│   └── requirements.R       # Package installation script for deployment
└── www/
    ├── custom.css            # Dark theme + design system
    └── custom.js             # Tab animations, crash count badge
```

## Data Source

NYC Motor Vehicle Collisions dataset (74,881 rows, 29 columns) covering all police-reported traffic accidents in New York City during 2020, from January until August.

## Predictive Model

A Gradient Boosting Machine (GBM) was trained to predict injury outcomes from pre-crash features (time, location, vehicle type). After rigorous evaluation (AUC = 0.635 across 4 algorithms), we concluded that spatial density analysis provides more actionable value to users than weak predictive scores. The full rationale is documented in `MODEL_DOCUMENTATION.md`. Model scripts are included for reproducibility.

## Tech Stack

- **R Shiny** with shinydashboard, shinyWidgets, shinyjs
- **Plotly** for interactive charts
- **Leaflet** for map visualisations
- **sf** for spatial operations (route buffering, hotspot detection)
- **OpenRouteService** for geocoding and routing
- **caret + GBM** for predictive modelling
- Custom CSS dark theme with design tokens (typography and spacing scales)

## How to Run Locally

1. Install R (>= 4.3) and all packages: `Rscript SETUP/requirements.R`
2. Set the ORS API key: add `ORS_API_KEY=your_key` to `~/.Renviron`
3. Ensure `DATA/processed_data.RData` exists (or run `source("data_processing.R")` — the source CSV is included at `DATA/NYC_Accidents_2020.csv`)
4. Run: `shiny::runApp(".")`

## Deployment

Deployed on AWS EC2 (Ubuntu 24.04, t2.large) via Shiny Server on port 3838.
