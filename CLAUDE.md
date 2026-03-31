# Data Analytics with R — Group Project

## Document System

- **CLAUDE.md** (this file): Project identity, grading criteria, and coding conventions. Auto-loaded every session. Rarely changes.
- **PLAN.md**: Architecture, full specifications, and phase-by-phase progress. **Read it at the start of every session.** Update it after completing each phase (instructions inside the file).

These two files together give a new session everything it needs. No other onboarding is required.

## Project

University group project (MiBA, Term 2). Building an R Shiny dashboard for the NYC Accidents 2020 dataset (`03 | DATA/NYC Accidents 2020.csv`, 74,881 rows). The app lives in `05 | RShiny-NYC-Dashboard/`. A Streamlit prototype (`prototype/app.py`) exists as a visual reference for layout and chart types.

## Grading Rubric

All four criteria matter equally. Every implementation decision should consider how it scores across these:

1. **Data preprocessing & coding style** — data loaded and cleaned, well-organized code
2. **UI/UX** — aesthetically pleasing, extra HTML/CSS/JS enhancements, intuitive
3. **Data visualizations** — clear, informative, adapted to visualization principles
4. **Predictive model** — well-chosen algorithm, evaluated, code provided (explicitly "highly valued")

## Conventions

- Structure R scripts with RStudio collapsible section headers (`# Title ====`, `## Subtitle ----`, `### Sub-section ----`) for outline panel navigation
- Write efficient, best-practice R code; clean and understandable
- when implementing a fix; ALWAYS identify and fix the root cause; NEVER fix the symptom in an isolated way, building on top of a persisting issue
- No hardcoded magic values -- use variables for anything used more than once
- No console prints (`cat()`, `print()` for status) -- document intent with `#` comments
- Preprocessing and model training run once offline, save `.RData` for fast app startup
- App entry point: `app.R` sources `ui.R` + `server.R`
- Static assets (CSS, JS) in `www/`
- Keep preprocessing, model training, UI, and server logic in separate files
- Deployment target: AWS EC2 (Ubuntu 24.04, t2.large) via Shiny Server on port 3838
