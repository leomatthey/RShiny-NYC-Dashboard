# Model Documentation — NYC Accidents Injury Prediction

## 1. Objective

We set out to build a predictive model for the Route Risk Predictor (Tab 5) that would predict whether a traffic accident results in an injury or fatality, given only pre-crash information (time, location, vehicle type). The goal was to score route segments so users could see not just where accidents happened, but how likely they were to be severe under specific conditions.

## 2. What We Built

### Target Variable

**ANY_INJURY** — binary (TRUE/FALSE). An accident is labelled TRUE if at least one person was injured or killed. The dataset has a 27.4% positive rate.

### Feature Selection

All features are knowable before an accident occurs (no post-hoc information):

| Feature | Type | Rationale |
|---------|------|-----------|
| HOUR | numeric (0-23) | Injury rates vary by time of day |
| DAY_OF_WEEK_NUM | numeric (1-7) | Weekend vs weekday patterns |
| MONTH_NUM | numeric (1-12) | Seasonal effects |
| IS_WEEKEND | logical | Binary weekend flag |
| IS_RUSH_HOUR | logical | Peak congestion periods |
| TIME_PERIOD | factor (4 levels) | Morning / Afternoon / Evening / Night |
| BOROUGH | factor (5 levels) | Borough-level geography |
| PRIMARY_VEHICLE | factor (7 levels) | Vehicle type involved |
| LATITUDE | numeric | Spatial location |
| LONGITUDE | numeric | Spatial location |

Features like FACTOR_CATEGORY, N_VEHICLES, and victim-type flags were excluded because they are only known after a crash occurs.

### Algorithm Comparison

Four algorithms were compared using 5-fold cross-validation on 38,156 training observations, optimising for ROC AUC:

| Algorithm | CV AUC | Test AUC |
|-----------|--------|----------|
| Logistic Regression (GLM) | 0.625 | 0.622 |
| Decision Tree (RPART) | 0.612 | 0.610 |
| Random Forest (RF) | 0.613 | 0.610 |
| **Gradient Boosting (GBM)** | **0.636** | **0.635** |

GBM was selected as the best-performing algorithm.

### Final Model Configuration

- **Algorithm:** GBM via `caret::train()` with 5-fold CV
- **Hyperparameters:** n.trees = 200, interaction.depth = 3, shrinkage = 0.1, n.minobsinnode = 10
- **Training set:** 38,156 rows (80%) | **Test set:** 9,538 rows (20%)
- **Stratified split** on ANY_INJURY to preserve class balance

## 3. Results

| Metric | Value |
|--------|-------|
| AUC | 0.635 |
| Accuracy | 75.5% |

### Top 5 Important Features

1. PRIMARY_VEHICLE (Bicycle / E-Bike) — 100% relative importance
2. MONTH_NUM — 58%
3. LONGITUDE — 48%
4. LATITUDE — 44%
5. HOUR — 41%

The model's calibration was sound: predicted probabilities aligned with observed injury rates across all probability bins.

## 4. Critical Evaluation

An AUC of 0.635 is modest. This is not a failure of methodology — it reflects a fundamental limitation of the prediction task. Injury severity in traffic accidents is driven by crash-specific factors: impact speed, collision angle, seatbelt use, pedestrian positioning, road surface conditions. None of these are knowable before an accident occurs.

With only pre-crash features (time, location, vehicle type), the model can capture broad patterns (cyclists are more vulnerable, certain intersections are riskier) but cannot meaningfully distinguish which specific future accident will cause injury versus property damage only. The 0.635 AUC is consistent across all four algorithms tested, confirming this is a ceiling imposed by the available features, not by the algorithm choice.

## 5. The Decision: Analysis Over Prediction

After evaluating the model, we asked: **does this prediction actually help the user?**

The Route Risk Predictor is designed for someone planning a trip through NYC who wants to understand the safety profile of their route. The question they are asking is not "will my next crash cause injury?" — it is "where are the dangerous spots, when should I be most careful, and what should I watch out for?"

A model that outputs a probability between 0.20 and 0.35 for every route segment does not meaningfully answer that question. The prediction is too uncertain to be actionable, and presenting it as a "risk score" would give users false confidence in a weak signal.

Instead, we chose to provide **direct analysis of historical accident data** along the route, which gives users concrete, interpretable, and genuinely useful information:

- **Hotspot detection:** The top 3 danger zones along the route, identified by spatial density clustering of historical crashes within 100m of sample points along the route. Each zone shows crash count, injury rate, and the most common contributing factor.
- **Temporal patterns:** When crashes happen by day of week and hour of day, so users can plan travel timing.
- **Vehicle type breakdown:** Which vehicle types are involved in corridor crashes and how severe they are, helping users understand mode-specific risks.
- **Contributing factors:** What causes crashes on this specific route, so users know what to watch for.

This approach provides more actionable value than a weak predictive score. A user seeing "47 crashes near Belt Parkway, mostly from distraction, peaking at 5 PM on Fridays" can make better decisions than seeing "risk score: 0.31."

## 6. Scripts Included

The model comparison and training scripts are included in the repository for full reproducibility:

| Script | Purpose |
|--------|---------|
| `model_comparison.R` | Compares GLM, Decision Tree, Random Forest, GBM via 5-fold CV |
| `model_training.R` | Trains the final GBM model with tuned hyperparameters |
| `DATA/model_comparison_results.txt` | Full comparison results and metrics |
| `DATA/model_comparison_dotplot.png` | Visual comparison of algorithm performance |

Model artifacts (final_model, conf_mat, roc_obj, var_imp, cal_df, test_df) remain in `DATA/processed_data.RData` for reproducibility.

## 7. Reproducibility

Both scripts use `set.seed(42)` and identical data preparation. Running `model_comparison.R` followed by `model_training.R` from the `05 | RShiny-NYC-Dashboard/` directory reproduces all results. The processed dataset (`data_processing.R`) must be generated first.
