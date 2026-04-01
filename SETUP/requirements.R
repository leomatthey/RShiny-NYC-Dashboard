# requirements.R — Install all R packages needed for the NYC Accidents Dashboard
# Run once on the server: sudo Rscript SETUP/requirements.R

packages <- c(
  # Shiny core
  "shiny", "shinydashboard", "shinyWidgets", "shinyjs",

  # Data manipulation
  "dplyr", "tidyr", "lubridate", "forcats", "glue",

  # Visualization
  "plotly", "leaflet", "leaflet.extras", "viridis", "scales", "DT",

  # Model (artifacts loaded from .RData, packages needed for object classes)
  "caret", "gbm", "pROC",

  # Spatial / routing
  "sf", "openrouteservice", "tidygeocoder"
)

# Install missing packages
installed <- rownames(installed.packages())
to_install <- setdiff(packages, installed)

if (length(to_install) > 0) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("All packages already installed.")
}
