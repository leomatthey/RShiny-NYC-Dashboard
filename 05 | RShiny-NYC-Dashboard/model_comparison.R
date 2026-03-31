# model_comparison.R — Algorithm Comparison for NYC Accidents 2020 =============
#
# Run once from 05 | RShiny-NYC-Dashboard/:
#   source("model_comparison.R")
#
# Compares 4 classification algorithms via 5-fold cross-validation to justify
# the final model choice for predicting ANY_INJURY.
#
# Output:
#   DATA/model_comparison_dotplot.png   — visual comparison
#   DATA/model_comparison_results.txt   — metrics summary + winner

# Setup ========================================================================

suppressPackageStartupMessages({
  library(caret)
  library(dplyr)
  library(pROC)
})

RDATA_PATH <- "DATA/processed_data.RData"
SEED       <- 42L

if (!file.exists(RDATA_PATH))
  stop("Processed data not found: ", RDATA_PATH,
       "\n  -> Run data_processing.R first.")

load(RDATA_PATH)

# Data Preparation =============================================================

## Feature and target definitions -----------------------------------------------

FEATURES <- c("HOUR", "DAY_OF_WEEK_NUM", "MONTH_NUM", "IS_WEEKEND",
              "IS_RUSH_HOUR", "TIME_PERIOD", "BOROUGH", "PRIMARY_VEHICLE",
              "LATITUDE", "LONGITUDE")
TARGET <- "ANY_INJURY"

## Build model-ready dataframe --------------------------------------------------
# Exclude Unknown borough (not useful for prediction), convert logicals to
# factors for consistent handling across all algorithms, drop incomplete rows.

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

# Cross-Validation Setup ======================================================

ctrl <- trainControl(
  method          = "cv",
  number          = 5,
  classProbs      = TRUE,
  summaryFunction = twoClassSummary
)

# Train Models =================================================================

## Logistic Regression (baseline) -----------------------------------------------

set.seed(SEED)
fit_glm <- train(
  ANY_INJURY ~ ., data = train_df,
  method    = "glm",
  family    = "binomial",
  metric    = "ROC",
  trControl = ctrl
)

## Decision Tree ----------------------------------------------------------------

set.seed(SEED)
fit_rpart <- train(
  ANY_INJURY ~ ., data = train_df,
  method     = "rpart",
  metric     = "ROC",
  trControl  = ctrl,
  tuneLength = 10
)

## Random Forest ----------------------------------------------------------------

set.seed(SEED)
fit_rf <- train(
  ANY_INJURY ~ ., data = train_df,
  method    = "rf",
  metric    = "ROC",
  trControl = ctrl,
  ntree     = 200,
  tuneGrid  = data.frame(mtry = c(2, 3, 4, 5))
)

## Gradient Boosting ------------------------------------------------------------

gbm_grid <- expand.grid(
  n.trees           = c(100, 200),
  interaction.depth = c(3, 5),
  shrinkage         = 0.1,
  n.minobsinnode    = 10
)

set.seed(SEED)
fit_gbm <- train(
  ANY_INJURY ~ ., data = train_df,
  method    = "gbm",
  metric    = "ROC",
  trControl = ctrl,
  tuneGrid  = gbm_grid,
  verbose   = FALSE
)

# Compare Models ===============================================================

## Resample comparison ----------------------------------------------------------

model_list <- list(
  GLM   = fit_glm,
  RPART = fit_rpart,
  RF    = fit_rf,
  GBM   = fit_gbm
)

resamp         <- resamples(model_list)
resamp_summary <- summary(resamp)

## Test set AUC -----------------------------------------------------------------

test_auc <- sapply(model_list, function(m) {
  probs <- predict(m, newdata = test_df, type = "prob")[, "Yes"]
  as.numeric(auc(roc(test_df$ANY_INJURY, probs,
                     levels = c("No", "Yes"), quiet = TRUE)))
})

## Identify winner --------------------------------------------------------------

winner_name <- names(which.max(test_auc))
winner_auc  <- max(test_auc)

# Save Results =================================================================

## Dot plot ---------------------------------------------------------------------

png("DATA/model_comparison_dotplot.png", width = 800, height = 500, res = 120)
dotplot(resamp, main = "Model Comparison \u2014 5-Fold CV (ROC, Sensitivity, Specificity)")
dev.off()

## Text summary -----------------------------------------------------------------

cv_means     <- resamp_summary$statistics
model_names  <- names(model_list)

header_lines <- c(
  "=== Model Comparison Results ===",
  "",
  "Target: ANY_INJURY (binary, ~27% positive class)",
  paste("Features:", paste(FEATURES, collapse = ", ")),
  sprintf("Training set: %d rows  |  Test set: %d rows", nrow(train_df), nrow(test_df)),
  ""
)

cv_lines <- c(
  "--- 5-Fold Cross-Validation (Mean) ---",
  sprintf("%-8s  %8s  %8s  %8s", "Model", "AUC", "Sens", "Spec"),
  sprintf("%-8s  %8s  %8s  %8s", "-----", "------", "------", "------")
)
for (m in model_names) {
  cv_lines <- c(cv_lines, sprintf(
    "%-8s  %8.4f  %8.4f  %8.4f",
    m,
    cv_means$ROC[m, "Mean"],
    cv_means$Sens[m, "Mean"],
    cv_means$Spec[m, "Mean"]
  ))
}

test_lines <- c(
  "",
  "--- Test Set AUC ---",
  sprintf("%-8s  %.4f", model_names, test_auc[model_names]),
  "",
  sprintf("Winner: %s (Test AUC = %.4f)", winner_name, winner_auc)
)

writeLines(c(header_lines, cv_lines, test_lines),
           "DATA/model_comparison_results.txt")
