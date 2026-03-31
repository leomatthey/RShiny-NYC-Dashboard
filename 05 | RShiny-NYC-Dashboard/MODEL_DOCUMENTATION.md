# Model Documentation — NYC Accidents Injury Prediction

## Objective

Predict whether a traffic accident in New York City will result in an injury (or fatality) versus property damage only. The model powers the Route Risk Predictor (Tab 5) in the Shiny dashboard, enabling users to assess risk along a planned route before any accident occurs.

## Target Variable

**ANY_INJURY** — binary (Yes / No). An accident is labelled "Yes" if at least one person was injured or killed. The dataset has a 27.4% positive rate (roughly 1 in 4 accidents causes injury).

## Feature Selection

All features must be knowable **before** an accident happens, since the model is used for prospective risk assessment on planned routes.

| Feature | Type | Rationale |
|---------|------|-----------|
| HOUR | numeric (0–23) | Injury rates vary sharply by time of day |
| DAY_OF_WEEK_NUM | numeric (1–7) | Weekend vs weekday patterns differ |
| MONTH_NUM | numeric (1–12) | Seasonal effects (weather, daylight) |
| IS_WEEKEND | factor | Binary weekend flag |
| IS_RUSH_HOUR | factor | 7–9 AM / 4–6 PM peak congestion |
| TIME_PERIOD | factor (4 levels) | Morning / Afternoon / Evening / Night |
| BOROUGH | factor (5 levels) | Borough-level geography |
| PRIMARY_VEHICLE | factor (7 levels) | Vehicle type of primary vehicle involved |
| LATITUDE | numeric | Fine-grained spatial location |
| LONGITUDE | numeric | Fine-grained spatial location |

### Excluded Features

| Feature | Reason |
|---------|--------|
| FACTOR_CATEGORY | Post-hoc: contributing factor is determined after the crash |
| N_VEHICLES | Post-hoc: number of vehicles involved is only known once the crash occurs |
| SEVERITY_LABEL | Derived from the target — would be data leakage |
| PED/CYC/MOT flags | Post-hoc victim information |

## Algorithm Selection

Four algorithms were compared using 5-fold cross-validation on 38,156 training observations, optimising for ROC AUC:

| Algorithm | CV AUC | Test AUC |
|-----------|--------|----------|
| Logistic Regression (GLM) | 0.6253 | 0.6218 |
| Decision Tree (RPART) | 0.6122 | 0.6096 |
| Random Forest (RF) | 0.6131 | 0.6097 |
| **Gradient Boosting (GBM)** | **0.6358** | **0.6343** |

**Winner: Gradient Boosting Machine (GBM)** — consistently highest AUC across both cross-validation and held-out test set.

The comparison code, dotplot, and full results are in `model_comparison.R` and `DATA/model_comparison_results.txt`.

## Final Model

**Algorithm:** GBM via `caret::train()` with 5-fold CV
**Hyperparameters:** n.trees = 200, interaction.depth = 3, shrinkage = 0.1, n.minobsinnode = 10
**Training set:** 38,156 rows (80%) | **Test set:** 9,538 rows (20%)
**Stratified split** on ANY_INJURY to preserve class balance.

### Performance on Test Set

| Metric | Value |
|--------|-------|
| AUC | 0.635 |
| Accuracy | 75.5% |

### Top 5 Important Features

1. PRIMARY_VEHICLE (Bicycle / E-Bike) — 100%
2. MONTH_NUM — 58%
3. LONGITUDE — 48%
4. LATITUDE — 44%
5. HOUR — 41%

Bicycle/E-Bike involvement is the strongest predictor of injury, consistent with the vulnerability of cyclists. Geographic coordinates (lat/lon) rank highly, confirming that location matters for injury severity. Temporal features (month, hour) capture seasonal and time-of-day risk patterns.

## Model Performance Context

An AUC of 0.635 is modest but expected. Injury severity in traffic accidents is fundamentally driven by crash-specific factors — impact speed, collision angle, seatbelt use, pedestrian involvement — none of which are knowable before the crash occurs.

The model's value is not in predicting individual outcomes with high precision. Instead, it provides **meaningful relative risk differentiation**: a predicted probability of 0.40 genuinely represents higher risk than 0.20. This is sufficient for ranking route segments and highlighting higher-risk areas and time windows.

The calibration data confirms the model is well-calibrated: predicted probabilities align with observed injury rates across all probability bins.

## Two-Stage Risk Assessment (Tab 5)

The Route Risk Predictor combines two complementary approaches:

### Stage 1 — Historical Spatial Density
The route polyline (obtained from the OSRM routing API) is buffered by 75 metres and spatially joined with all 74,881 historical accidents. This identifies:
- **Dangerous intersections** with high accident counts
- **Hotspot streets** along the route
- **Top contributing factors** in the area

This stage answers: *"Where have accidents happened near this route?"*

### Stage 2 — Predictive Model
The GBM model scores each route segment using the user's selected conditions (time of day, day of week, vehicle type) plus the segment's coordinates. This adds:
- **Temporal context**: "This area is riskier at night"
- **Vehicle-specific risk**: "Cyclists face higher injury risk here"
- **Seasonal patterns**: "Winter months increase severity"

This stage answers: *"Given these conditions, how severe would an accident be?"*

### Combined Output
The two stages are combined to produce:
- A **risk-coloured route** (green → amber → red)
- A **risk score** (0–100%)
- **Hotspot warnings** for specific intersections
- **Contextual advice** based on the top risk factors

## Artifacts

All model artifacts are stored in `DATA/processed_data.RData`:

| Object | Description |
|--------|-------------|
| final_model | Trained caret GBM model object |
| conf_mat | Confusion matrix (confusionMatrix object) |
| roc_obj | pROC::roc object for ROC curve plotting |
| var_imp | Variable importance (varImp object) |
| cal_df | Calibration data — 10 bins of predicted vs observed rates |
| test_df | Held-out test set (9,538 rows) for reproducibility |

## Reproducibility

Both scripts use `set.seed(42)` and identical data preparation steps. Running `model_comparison.R` followed by `model_training.R` from the `05 | RShiny-NYC-Dashboard/` directory reproduces all results. The processed dataset (`data_processing.R`) must be generated first.
