# global.R — NYC Traffic Accidents 2020 Dashboard (Shared Setup)
# ============================================================================
# Loaded once at app startup before ui.R and server.R.

# Load Packages ====
library(shiny)
library(shinydashboard)
library(shinyWidgets)
library(shinyjs)
library(dplyr)
library(tidyr)
library(lubridate)
library(forcats)
library(plotly)
library(leaflet)
library(leaflet.extras)
library(viridis)
library(scales)
library(DT)
library(glue)
library(caret)
library(gbm)
library(pROC)
library(sf)
library(openrouteservice)
library(tidygeocoder)

# Load Preprocessed Data ====
load("DATA/processed_data.RData")
# Objects available: df (74,881 x 48), 10 summary tables, 6 model artifacts

# Shared Constants ====

## Color palettes ----
SEVERITY_COLORS <- c(
  "Property Damage Only" = "#5d6d7e",
  "Injury"               = "#f39c12",
  "Severe Injury"        = "#e67e22",
  "Fatal"                = "#e74c3c"
)

FACTOR_COLORS <- c(
  "Distraction"            = "#e74c3c",
  "Speed"                  = "#e67e22",
  "Impairment"             = "#9b59b6",
  "Following Too Closely"  = "#f39c12",
  "Traffic Violation"      = "#3498db",
  "Visibility"             = "#1abc9c",
  "Driver Condition"       = "#e91e63",
  "Environmental / Vehicle"= "#5d6d7e",
  "Vulnerable Road User"   = "#27ae60",
  "Other / Unknown"        = "#656d76"
)

## Ordered factor levels ----
SEVERITY_ORDER  <- c("Property Damage Only", "Injury", "Severe Injury", "Fatal")
BOROUGH_ORDER   <- c("Manhattan", "Brooklyn", "Queens", "Bronx", "Staten Island")

## Data-driven month range ----
MAX_MONTH <- max(df$MONTH_NUM)

## Sidebar filter choices ----
BOROUGH_CHOICES  <- BOROUGH_ORDER
SEVERITY_CHOICES <- SEVERITY_ORDER

## Plotly dark layout defaults ----
PLOTLY_LAYOUT <- list(
  paper_bgcolor = "#1c2128",
  plot_bgcolor  = "#1c2128",
  font          = list(color = "#e6edf3", family = "Inter, system-ui, sans-serif", size = 12),
  legend        = list(bgcolor = "rgba(0,0,0,0)", bordercolor = "#30363d", borderwidth = 1,
                        font = list(size = 11)),
  margin        = list(l = 50, r = 20, t = 40, b = 50)
)

PLOTLY_XAXIS <- list(gridcolor = "#21262d", zerolinecolor = "#30363d", color = "#8b949e")
PLOTLY_YAXIS <- list(gridcolor = "#21262d", zerolinecolor = "#30363d", color = "#8b949e")

# Route Risk Predictor Constants ====

## Map-specific severity colors — lighter PDO for dark tile visibility ----
CRASH_MAP_COLORS <- c(
  "Property Damage Only" = "#95a5a6",
  "Injury"               = "#f39c12",
  "Severe Injury"        = "#e67e22",
  "Fatal"                = "#e74c3c"
)

## Citywide accident density baseline ----
NYC_ROAD_KM      <- 9600L
CITYWIDE_DENSITY <- list(all = nrow(df) / NYC_ROAD_KM)

## Danger zone detection ----
HOTSPOT_RADIUS      <- 100L   # metres — crash search radius around each sample point
HOTSPOT_MIN_SEP     <- 200L   # metres — minimum distance between zone centers
HOTSPOT_MIN_CRASHES <- 3L     # minimum crashes to qualify as a zone
HOTSPOT_SAMPLE_STEP <- 50L    # metres between sample points for peak detection

## ORS API ----
ORS_API_KEY <- Sys.getenv("ORS_API_KEY")
ors_api_key(ORS_API_KEY)

## Route spatial params ----
ROUTE_SAMPLE_INTERVAL <- 200   # metres between sample points (used in Part 2)
ROUTE_BUFFER_RADIUS   <- 25L   # metres each side → 50m total corridor width
CRS_WGS84 <- 4326L
CRS_NYC   <- 32618L            # UTM Zone 18N (metric)

## Pre-computed spatial objects (built once at startup) ----
borough_ref_sf <- df %>%
  filter(VALID_COORDS, BOROUGH != "Unknown") %>%
  select(LATITUDE, LONGITUDE, BOROUGH) %>%
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = CRS_WGS84)

accident_sf <- df %>%
  filter(VALID_COORDS) %>%
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = CRS_WGS84) %>%
  st_transform(CRS_NYC)
