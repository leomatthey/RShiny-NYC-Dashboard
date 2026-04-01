# NYC Traffic Accidents 2020 Dashboard

A full-stack interactive dashboard built with R Shiny, analysing 74,881 traffic accidents across New York City's five boroughs. Features 25+ interactive visualisations, a custom dark theme design system, and a route risk analysis tool with spatial hotspot detection.

**[Live Demo](http://15.188.143.227:3838/nyc-dashboard/)**

---

## Preview

### Welcome Screen
The app opens with a splash overlay introducing the project scope and key statistics before users enter the dashboard.

### Dashboard Features

| Tab | Description |
|-----|-------------|
| **Overview** | KPI cards, borough comparisons, victim breakdowns, hourly distributions, severity patterns |
| **Interactive Map** | Leaflet heatmap/marker toggle with 68,000+ geocoded crash points and dangerous street rankings |
| **Time Analysis** | Hour x day-of-week heatmap, day/month patterns, victim type by time, borough-level temporal trends |
| **Causes & Vehicles** | Contributing factor rankings, severity profiles, category trends, vehicle type breakdowns |
| **Route Risk** | Enter any NYC route to see density-coloured risk segments, automated danger zone detection, and corridor-specific analytics |

---

## Key Technical Highlights

### Design System
Custom CSS with centralised design tokens for typography (5-level scale) and spacing (4-level scale), ensuring visual consistency across all pages. Dark theme inspired by GitHub's colour palette.

### Route Risk Analysis
- **OpenRouteService** geocoding with live address autocomplete
- Route polyline coloured yellow-to-red by historical crash density
- **Hotspot detection**: peak-finding algorithm samples points along the route, counts crashes within 100m radius, and identifies the top 3 danger zones with 200m minimum separation
- Per-zone statistics: crash count, injury rate, top contributing factor
- Clickable zone cards that fly the map to each hotspot

### Predictive Modelling
Four classification algorithms (GLM, Decision Tree, Random Forest, GBM) were compared via 5-fold cross-validation to predict injury outcomes. After evaluation (best AUC = 0.635), we made the deliberate decision to replace weak predictions with spatial density analysis that provides more actionable user value. Full methodology documented in [`MODEL_DOCUMENTATION.md`](MODEL_DOCUMENTATION.md).

---

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| **Frontend** | shinydashboard, shinyWidgets, shinyjs, custom CSS/JS |
| **Visualisation** | Plotly (21 charts), Leaflet (2 maps), DT (interactive tables) |
| **Spatial** | sf, OpenRouteService API (geocoding + routing) |
| **Modelling** | caret, GBM, pROC |
| **Data** | dplyr, tidyr, lubridate, forcats |
| **Deployment** | AWS EC2 (Ubuntu 24.04), Shiny Server |

---

## Project Structure

```
├── app.R                    # Entry point
├── global.R                 # Packages, constants, shared data
├── ui.R                     # Dashboard layout (sidebar + 5 tabs)
├── server.R                 # Reactive logic, 25+ outputs
├── data_processing.R        # Raw CSV -> processed RData (run once)
├── model_comparison.R       # 4-algorithm comparison pipeline
├── model_training.R         # Final GBM training + evaluation
├── MODEL_DOCUMENTATION.md   # Modelling methodology and rationale
├── DATA/
│   ├── NYC_Accidents_2020.csv
│   └── processed_data.RData
├── SETUP/
│   └── requirements.R
└── www/
    ├── custom.css            # Design system (980 lines)
    └── custom.js             # Animations + interactivity
```

## Getting Started

```bash
# Install dependencies
Rscript SETUP/requirements.R

# (Optional) Set ORS API key for Route Risk autocomplete
echo 'ORS_API_KEY=your_key' >> ~/.Renviron

# Launch
Rscript -e 'shiny::runApp(".")'
```

The app runs fully without the ORS key — only the Route Risk address autocomplete requires it.

---

## Data

NYC Motor Vehicle Collisions dataset: 74,881 police-reported accidents from January to August 2020, covering all five boroughs. Features include crash location (lat/lon), date/time, contributing factors, vehicle types, and injury/fatality counts.

---

Built with R 4.3 | Deployed on AWS EC2 | Dark theme with Inter typeface
