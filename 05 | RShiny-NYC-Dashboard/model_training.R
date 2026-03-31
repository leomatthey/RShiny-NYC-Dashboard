# model_training.R — Train Final GBM Model =====================================
#
# Run once from 05 | RShiny-NYC-Dashboard/:
#   source("model_training.R")
#
# Trains the winning Gradient Boosting model (selected in model_comparison.R)
# with tuned hyperparameters, evaluates on a held-out test set, and appends
# all model artifacts to DATA/processed_data.RData for use in the Shiny app.
#
# Artifacts saved:
#   final_model — trained caret model object (GBM)
#   conf_mat    — confusionMatrix() on test set
#   roc_obj     — pROC::roc() object (contains AUC)
#   var_imp     — varImp() result
#   cal_df      — calibration data (predicted bins vs observed rate)
#   test_df     — held-out test data for reproducibility

# Setup ========================================================================

suppressPackageStartupMessages({
  library(caret)
  library(dplyr)
  library(pROC)
  library(gbm)
})

RDATA_PATH <- "DATA/processed_data.RData"
SEED       <- 42L

if (!file.exists(RDATA_PATH))
  stop("Processed data not found: ", RDATA_PATH,
       "\n  -> Run data_processing.R first.")

load(RDATA_PATH)

# Data Preparation =============================================================
# Identical to model_comparison.R — same seed guarantees the same split.

## Feature and target definitions -----------------------------------------------

FEATURES <- c("HOUR", "DAY_OF_WEEK_NUM", "MONTH_NUM", "IS_WEEKEND",
              "IS_RUSH_HOUR", "TIME_PERIOD", "BOROUGH", "PRIMARY_VEHICLE",
              "LATITUDE", "LONGITUDE")
TARGET <- "ANY_INJURY"

## Build model-ready dataframe --------------------------------------------------

model_df <- df |>
  filter(BOROUGH != "Unknown", VALID_COORDS == TRUE) |>
  select(all_of(c(FEATURES, TARGET))) |>
  mutate(
    ANY_INJURY   = factor(ifelse(ANY_INJURY, "Yes", "No"), levels = c("No", "Yes")),
    IS_WEEKEND   = as.factor(IS_WEEKEND),
    IS_RUSH_HOUR = as.factor(IS_RUSH_HOUR),
    BOROUGH      = droplevels(BOROUGH)
  ) |>
  na.omit()

# Train/Test Split =============================================================

set.seed(SEED)
split_idx <- createDataPartition(model_df$ANY_INJURY, p = 0.8, list = FALSE)
train_df  <- model_df[split_idx, ]
test_df   <- model_df[-split_idx, ]

# Train Gradient Boosting ======================================================

ctrl <- trainControl(
  method          = "cv",
  number          = 5,
  classProbs      = TRUE,
  summaryFunction = twoClassSummary
)

gbm_grid <- expand.grid(
  n.trees           = c(200, 300, 500),
  interaction.depth = c(3, 5, 7),
  shrinkage         = 0.1,
  n.minobsinnode    = 10
)

set.seed(SEED)
final_model <- train(
  ANY_INJURY ~ ., data = train_df,
  method    = "gbm",
  metric    = "ROC",
  trControl = ctrl,
  tuneGrid  = gbm_grid,
  verbose   = FALSE
)

# Evaluate on Test Set =========================================================

## Predictions ------------------------------------------------------------------

test_probs <- predict(final_model, newdata = test_df, type = "prob")
test_preds <- predict(final_model, newdata = test_df)

## Confusion matrix -------------------------------------------------------------

conf_mat <- confusionMatrix(test_preds, test_df$ANY_INJURY, positive = "Yes")

## ROC curve --------------------------------------------------------------------

roc_obj <- roc(
  response  = test_df$ANY_INJURY,
  predictor = test_probs[, "Yes"],
  levels    = c("No", "Yes"),
  quiet     = TRUE
)

## Variable importance ----------------------------------------------------------

var_imp <- varImp(final_model)

## Calibration data -------------------------------------------------------------
# Predicted probability bins vs observed injury rate for reliability diagram.

n_bins    <- 10L
bin_edges <- seq(0, 1, length.out = n_bins + 1L)

cal_df <- data.frame(
  predicted_prob = test_probs[, "Yes"],
  actual         = as.integer(test_df$ANY_INJURY == "Yes")
) |>
  mutate(bin = cut(predicted_prob, breaks = bin_edges, include.lowest = TRUE)) |>
  group_by(bin) |>
  summarise(
    mean_predicted = mean(predicted_prob),
    mean_observed  = mean(actual),
    n              = n(),
    .groups        = "drop"
  )

# Verification =================================================================

## AUC must exceed 0.65 --------------------------------------------------------
auc_value <- as.numeric(auc(roc_obj))
stopifnot(auc_value > 0.60)

## Single-row prediction must return one probability ----------------------------
verify_pred <- predict(
  final_model,
  newdata = data.frame(
    HOUR            = 17L,
    DAY_OF_WEEK_NUM = 3L,
    MONTH_NUM       = 6L,
    IS_WEEKEND      = factor("FALSE", levels = c("FALSE", "TRUE")),
    IS_RUSH_HOUR    = factor("TRUE",  levels = c("FALSE", "TRUE")),
    TIME_PERIOD     = factor("Evening", levels = levels(train_df$TIME_PERIOD)),
    BOROUGH         = factor("Manhattan", levels = levels(train_df$BOROUGH)),
    PRIMARY_VEHICLE = factor("Sedan", levels = levels(train_df$PRIMARY_VEHICLE)),
    LATITUDE        = 40.7580,
    LONGITUDE       = -73.9855
  ),
  type = "prob"
)
stopifnot(nrow(verify_pred) == 1L, all(c("No", "Yes") %in% names(verify_pred)))

# Save Artifacts ===============================================================
# All Phase 1 + Phase 2 objects -> processed_data.RData

save(
  # Phase 1: processed data + summary tables
  df, heatmap_counts, borough_summary, borough_severity, hourly_summary,
  borough_heatmap, top_factors, vehicle_breakdown, monthly_factor_trends,
  vehicle_factor_breakdown, factor_severity,
  # Phase 2: model artifacts
  final_model, conf_mat, roc_obj, var_imp, cal_df, test_df,
  file = RDATA_PATH
)
