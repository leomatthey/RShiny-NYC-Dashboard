# data_processing.R — NYC Accidents 2020 ======================================
#
# Run once from 05 | RShiny-NYC-Dashboard/:
#   source("data_processing.R")
#
# Output: DATA/processed_data.RData
#   Objects: df, heatmap_counts, borough_summary, borough_severity,
#            hourly_summary, borough_heatmap, top_factors,
#            vehicle_breakdown, monthly_factor_trends,
#            vehicle_factor_breakdown, factor_severity

# Setup =======================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
  library(forcats)
})

DATA_IN  <- "../03 | DATA/NYC Accidents 2020.csv"
DATA_OUT <- "DATA/processed_data.RData"

if (!file.exists(DATA_IN))
  stop("Data not found: ", DATA_IN,
       "\n  -> Run this script from the 05 | RShiny-NYC-Dashboard/ directory.")

if (!dir.exists("DATA")) dir.create("DATA")

# Load & Normalise ============================================================

raw <- read_csv(DATA_IN, show_col_types = FALSE)

# Uppercase + underscores: "CRASH DATE" -> "CRASH_DATE"
df <- raw |>
  rename_with(~ str_replace_all(str_to_upper(.), "\\s+", "_"))

# Feature Engineering =========================================================

## Temporal Features -----------------------------------------------------------

df <- df |>
  mutate(
    CRASH_DATETIME = parse_date_time(
      paste(CRASH_DATE, CRASH_TIME), orders = "ymd HMS", quiet = TRUE
    ),
    HOUR            = hour(CRASH_DATETIME),
    DAY_OF_WEEK_NUM = wday(CRASH_DATETIME, week_start = 1L),        # 1 = Mon
    DAY_OF_WEEK     = wday(CRASH_DATETIME, label = TRUE, abbr = FALSE,
                           week_start = 1L) |> as.character(),
    MONTH_NUM       = month(CRASH_DATETIME),
    MONTH           = month(CRASH_DATETIME, label = TRUE, abbr = FALSE) |>
                        as.character(),
    IS_WEEKEND      = DAY_OF_WEEK_NUM %in% c(6L, 7L),
    IS_RUSH_HOUR    = (HOUR >= 7L & HOUR <= 9L) | (HOUR >= 16L & HOUR <= 18L),
    TIME_PERIOD     = factor(
      case_when(
        HOUR >= 6L  & HOUR < 12L ~ "Morning",
        HOUR >= 12L & HOUR < 17L ~ "Afternoon",
        HOUR >= 17L & HOUR < 21L ~ "Evening",
        TRUE                     ~ "Night"
      ),
      levels = c("Morning", "Afternoon", "Evening", "Night")
    )
  )

## Geographic Cleaning ---------------------------------------------------------

df <- df |>
  mutate(
    BOROUGH = str_to_title(BOROUGH) |>
      replace_na("Unknown") |>
      factor(levels = c("Manhattan", "Brooklyn", "Queens",
                        "Bronx", "Staten Island", "Unknown")),
    VALID_COORDS = !is.na(LATITUDE) & !is.na(LONGITUDE) &
                   between(LATITUDE,   40.40,  40.95) &
                   between(LONGITUDE, -74.30, -73.60)
  )

## Severity --------------------------------------------------------------------
# Fatal > Severe Injury (>=3 injured) > Injury (>=1 injured) > PDO

df <- df |>
  rename(
    PERSONS_INJURED = NUMBER_OF_PERSONS_INJURED,
    PERSONS_KILLED  = NUMBER_OF_PERSONS_KILLED,
    PED_INJURED     = NUMBER_OF_PEDESTRIANS_INJURED,
    PED_KILLED      = NUMBER_OF_PEDESTRIANS_KILLED,
    CYC_INJURED     = NUMBER_OF_CYCLIST_INJURED,
    CYC_KILLED      = NUMBER_OF_CYCLIST_KILLED,
    MOT_INJURED     = NUMBER_OF_MOTORIST_INJURED,
    MOT_KILLED      = NUMBER_OF_MOTORIST_KILLED
  ) |>
  mutate(
    SEVERITY_LABEL = factor(
      case_when(
        PERSONS_KILLED  >= 1L ~ "Fatal",
        PERSONS_INJURED >= 3L ~ "Severe Injury",
        PERSONS_INJURED >= 1L ~ "Injury",
        TRUE                  ~ "Property Damage Only"
      ),
      levels = c("Property Damage Only", "Injury", "Severe Injury", "Fatal")
    ),
    ANY_INJURY   = PERSONS_INJURED > 0L | PERSONS_KILLED > 0L,
    PED_INVOLVED = PED_INJURED     > 0L | PED_KILLED    > 0L,
    CYC_INVOLVED = CYC_INJURED     > 0L | CYC_KILLED    > 0L,
    MOT_INVOLVED = MOT_INJURED     > 0L | MOT_KILLED    > 0L
  )

## Contributing Factor Consolidation -------------------------------------------
# Map raw NYPD factor strings -> 9 interpretable categories

### categorise_factor() --------------------------------------------------------

categorise_factor <- function(x) {
  x <- str_to_lower(x)
  case_when(
    str_detect(x, paste(
      "inattention", "distraction", "cell phone", "texting",
      "electronic", "outside car", "eating", "drinking",
      "headphones", "navigation device", "radio",
      sep = "|"))
      ~ "Distraction",
    str_detect(x, "unsafe speed|speeding|racing")
      ~ "Speed",
    str_detect(x, "alcohol|drug|illegal|medication|marijuana|cannabis")
      ~ "Impairment",
    str_detect(x, "following too closely")
      ~ "Following Too Closely",
    str_detect(x, paste(
      "fatigue", "drowsy", "fell asleep", "lost consciousness",
      "illnes", "physical disab", "driver inexperience",
      "aggressive", "road rage",
      sep = "|"))
      ~ "Driver Condition",
    str_detect(x, "view obstructed|glare|visibility|windshield|sun|tinted window")
      ~ "Visibility",
    str_detect(x, paste(
      "yield", "traffic control", "signal", "lane changing",
      "turning", "backing", "pavement marking", "wrong side",
      "failure to keep right", "unsafe lane", "lane usage",
      "\\bpassing\\b", "cutting", "reaction to uninvolved",
      "drifted", "rolled from parked",
      sep = "|"))
      ~ "Traffic Violation",
    str_detect(x, paste(
      "pavement", "tire", "brake", "steering",
      "headlight", "vehicle defect", "mechanical", "animal",
      "debris", "slippery", "road surface", "other vehicular",
      "oversized vehicle", "driverless", "runaway vehicle",
      "accelerator", "lighting defect", "tow hitch",
      "shoulders defect", "lane marking",
      sep = "|"))
      ~ "Environmental / Vehicle",
    str_detect(x, "pedestrian|bicyclist|cyclist|other pedestrian")
      ~ "Vulnerable Road User",
    TRUE ~ "Other / Unknown"
  )
}

### Primary factor per collision -----------------------------------------------
# Pick the first non-"Unspecified" factor across the 5 vehicle slots

factor_primary <- df |>
  select(COLLISION_ID, matches("CONTRIBUTING_FACTOR_VEHICLE_\\d")) |>
  pivot_longer(
    cols      = -COLLISION_ID,
    names_to  = "slot",
    values_to = "factor"
  ) |>
  filter(!is.na(factor),
         !str_to_lower(str_trim(factor)) %in% c("unspecified", "")) |>
  group_by(COLLISION_ID) |>
  slice(1L) |>
  ungroup() |>
  select(COLLISION_ID, PRIMARY_FACTOR = factor)

df <- df |>
  left_join(factor_primary, by = "COLLISION_ID") |>
  mutate(
    PRIMARY_FACTOR  = replace_na(PRIMARY_FACTOR, "Unspecified"),
    FACTOR_CATEGORY = factor(
      categorise_factor(PRIMARY_FACTOR),
      levels = c(
        "Distraction", "Speed", "Impairment",
        "Following Too Closely", "Traffic Violation",
        "Visibility", "Driver Condition",
        "Environmental / Vehicle", "Vulnerable Road User",
        "Other / Unknown"
      )
    )
  )

## Vehicle Type Consolidation --------------------------------------------------

### categorise_vehicle() -------------------------------------------------------

categorise_vehicle <- function(x) {
  x <- str_to_lower(str_trim(x))
  case_when(
    str_detect(x, "sedan|convertible|passenger vehicle|small com veh|2 dr|4 dr")
      ~ "Sedan",
    str_detect(x, "station wagon|sport utility|suv|minivan|mini van|limo")
      ~ "SUV / Wagon",
    str_detect(x, "taxi|livery|black car|for hire|van cab|commuter van")
      ~ "Taxi / Livery",
    str_detect(x, "pick.?up|box truck|\\bvan\\b|\\bbus\\b|truck|tractor|trailer|garbage|refuse|dump|tanker|cement|fire truck|large com")
      ~ "Truck / Van / Bus",
    str_detect(x, "motorcycle|motor cycle|motorbike|motor bike|moped|\\bscooter\\b|dirt bike|e-scooter|motorscooter")
      ~ "Motorcycle / Scooter",
    str_detect(x, "bicycle|\\bbike\\b|e-bike|ebike|e bike|pedicab|electric bicycle")
      ~ "Bicycle / E-Bike",
    TRUE ~ "Other"
  )
}

### Primary vehicle per collision ----------------------------------------------
# Pick the first non-NA vehicle type across the 5 vehicle slots

vehicle_primary <- df |>
  select(COLLISION_ID, matches("VEHICLE_TYPE_CODE_\\d")) |>
  pivot_longer(
    cols      = -COLLISION_ID,
    names_to  = "slot",
    values_to = "vehicle"
  ) |>
  filter(!is.na(vehicle), str_trim(vehicle) != "") |>
  group_by(COLLISION_ID) |>
  slice(1L) |>
  ungroup() |>
  select(COLLISION_ID, PRIMARY_VEHICLE_RAW = vehicle)

df <- df |>
  left_join(vehicle_primary, by = "COLLISION_ID") |>
  mutate(
    PRIMARY_VEHICLE = factor(
      categorise_vehicle(replace_na(PRIMARY_VEHICLE_RAW, "unknown")),
      levels = c("Sedan", "SUV / Wagon", "Taxi / Livery",
                 "Truck / Van / Bus", "Motorcycle / Scooter",
                 "Bicycle / E-Bike", "Other")
    )
  ) |>
  select(-PRIMARY_VEHICLE_RAW)

## Vehicle Count ---------------------------------------------------------------

df <- df |>
  mutate(
    N_VEHICLES = rowSums(!is.na(pick(matches("VEHICLE_TYPE_CODE_\\d"))))
  )

# Pre-Aggregated Summary Tables ================================================
# Full-dataset aggregations for charts that should NOT react to sidebar
# filters (e.g. full-year trend lines, reference heatmaps).
# Filter-responsive charts compute aggregations in server.R instead.

## Hour x Day-of-Week Heatmap (Tab 3) -----------------------------------------

heatmap_counts <- df |>
  group_by(HOUR, DAY_OF_WEEK_NUM, DAY_OF_WEEK) |>
  summarise(
    crashes = n(),
    injured = sum(PERSONS_INJURED, na.rm = TRUE),
    .groups = "drop"
  )

## Borough Summary (Tab 1 dual-axis) -------------------------------------------

borough_summary <- df |>
  filter(BOROUGH != "Unknown") |>
  group_by(BOROUGH) |>
  summarise(
    crashes    = n(),
    injured    = sum(PERSONS_INJURED,  na.rm = TRUE),
    killed     = sum(PERSONS_KILLED,   na.rm = TRUE),
    pct_injury = round(mean(ANY_INJURY, na.rm = TRUE) * 100, 1),
    .groups    = "drop"
  )

## Borough x Severity (Tab 1 stacked bar) -------------------------------------

borough_severity <- df |>
  filter(BOROUGH != "Unknown") |>
  count(BOROUGH, SEVERITY_LABEL, name = "n") |>
  group_by(BOROUGH) |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  ungroup()

## Hourly Distribution (Tab 1 overview bar) ------------------------------------

hourly_summary <- df |>
  group_by(HOUR) |>
  summarise(
    crashes    = n(),
    injured    = sum(PERSONS_INJURED, na.rm = TRUE),
    pct_injury = round(mean(ANY_INJURY, na.rm = TRUE) * 100, 1),
    .groups    = "drop"
  )

## Hour x Borough Heatmap (Tab 3) ----------------------------------------------

borough_heatmap <- df |>
  filter(BOROUGH != "Unknown") |>
  count(HOUR, BOROUGH, name = "crashes")

## Top 20 Contributing Factors (Tab 4) -----------------------------------------

top_factors <- df |>
  filter(PRIMARY_FACTOR != "Unspecified") |>
  group_by(PRIMARY_FACTOR, FACTOR_CATEGORY) |>
  summarise(
    crashes    = n(),
    pct_injury = round(mean(ANY_INJURY, na.rm = TRUE) * 100, 1),
    .groups    = "drop"
  ) |>
  slice_max(crashes, n = 20L)

## Vehicle x Severity (Tab 4 stacked bar) --------------------------------------

vehicle_breakdown <- df |>
  count(PRIMARY_VEHICLE, SEVERITY_LABEL, name = "n") |>
  group_by(PRIMARY_VEHICLE) |>
  mutate(
    total = sum(n),
    pct   = round(n / total * 100, 2)
  ) |>
  ungroup()

## Monthly Factor Trends (Tab 4 line chart) ------------------------------------

monthly_factor_trends <- df |>
  filter(as.character(FACTOR_CATEGORY) != "Other / Unknown") |>
  count(MONTH_NUM, MONTH, FACTOR_CATEGORY, name = "crashes")

## Vehicle x Factor Breakdown (Tab 4 stacked bar) ------------------------------

vehicle_factor_breakdown <- df |>
  filter(as.character(FACTOR_CATEGORY) != "Other / Unknown") |>
  count(PRIMARY_VEHICLE, FACTOR_CATEGORY, name = "n") |>
  group_by(PRIMARY_VEHICLE) |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  ungroup()

## Factor Severity Profile (Tab 4 stacked bar) ---------------------------------

factor_severity <- df |>
  filter(as.character(FACTOR_CATEGORY) != "Other / Unknown") |>
  count(FACTOR_CATEGORY, SEVERITY_LABEL, name = "n") |>
  group_by(FACTOR_CATEGORY) |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  ungroup()

# Save =========================================================================
# df + 10 summary tables -> DATA/processed_data.RData

save(
  df,
  heatmap_counts,
  borough_summary,
  borough_severity,
  hourly_summary,
  borough_heatmap,
  top_factors,
  vehicle_breakdown,
  monthly_factor_trends,
  vehicle_factor_breakdown,
  factor_severity,
  file = DATA_OUT
)
