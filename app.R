# app.R — NYC Traffic Accidents 2020 Dashboard (Entry Point)
# ============================================================================
# global.R is auto-sourced by Shiny before ui.R and server.R.

source("global.R")
source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
