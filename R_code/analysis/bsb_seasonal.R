# =============================================================================
# Script:  bsb_seasonal.R
# Purpose: Exploratory analysis of seasonal patterns in BSB weekly landings
#          by state.  Examines within-year seasonality and state-level trends.
#          Display-only: graphs are printed to the R viewer but not exported
#          (consistent with the Stata original, which displays but does not
#          export any graphics).
# Inputs:  data_folder/main/commercial/weekly_landings_{in_string}.Rds
# Outputs: None — plots displayed in R session only
# Notes:   Ported from stata_code/analysis/bsb_seasonal.do
#          in_string must be set before sourcing (via wrapper or manually).
#          States excluded per Stata: CN, FL, ME, NH, NK, PA, SC.
# =============================================================================


if (!exists("in_string")) {
  stop("'in_string' not defined. Run via 00_exploratory_analysis_wrapper.R or set in_string manually.")
}


# =============================================================================
# Load weekly landings
# =============================================================================

weekly <- readRDS(
  here("data_folder", "main", "commercial",  glue("weekly_landings_{in_string}.Rds"))
)

# States to exclude (Stata: drop if inlist(state, "CN","FL","ME","NH","NK","PA","SC"))
exclude_states <- c("CN", "FL", "ME", "NH", "NK", "PA", "SC")

weekly_filt <- weekly %>%
  filter(!state %in% exclude_states)


# =============================================================================
# Plot 1: Box plot of landings by week (all states)
# Stata: graph box landings, over(week)
# =============================================================================

p1 <- ggplot(weekly, aes(x = factor(week), y = landings)) +
  geom_boxplot(outlier.shape = NA) +
  labs(x = "Week", y = "Landings (lbs)",
       title = "BSB weekly landings — all states, all years") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6))
print(p1)


# =============================================================================
# Plot 2: Time series by state (xtline equivalent — faceted)
# Stata: xtline landings if keep==1
# =============================================================================

p2 <- ggplot(weekly_filt, aes(x = year + week / 52, y = landings)) +
  geom_line(linewidth = 0.4) +
  facet_wrap(~ state, scales = "free_y") +
  labs(x = "Year", y = "Landings (lbs)",
       title = "BSB weekly landings by state (Atlantic states only)") +
  theme_bw(base_size = 8)
print(p2)


# =============================================================================
# Plots 3-4: CT and RI individual time series
# Stata: tsline landings if state=="CT"; tsline landings if state=="RI"
# =============================================================================

p3 <- ggplot(filter(weekly_filt, state == "CT"),
             aes(x = year + week / 52, y = landings)) +
  geom_line() +
  labs(x = "Year", y = "Landings (lbs)", title = "CT weekly BSB landings") +
  theme_bw()
print(p3)

p4 <- ggplot(filter(weekly_filt, state == "RI"),
             aes(x = year + week / 52, y = landings)) +
  geom_line() +
  labs(x = "Year", y = "Landings (lbs)", title = "RI weekly BSB landings") +
  theme_bw()
print(p4)


# =============================================================================
# Plots 5-6: Box plots by week for MD and RI
# Stata: graph box landings if state=="MD", over(week,label(angle(45)))
#        graph box landings if state=="RI", over(week,label(angle(45)))
# =============================================================================

p5 <- ggplot(filter(weekly_filt, state == "MD"),
             aes(x = factor(week), y = landings)) +
  geom_boxplot(outlier.shape = NA) +
  labs(x = "Week", y = "Landings (lbs)",
       title = "MD weekly BSB landings — distribution by week") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6))
print(p5)

p6 <- ggplot(filter(weekly_filt, state == "RI"),
             aes(x = factor(week), y = landings)) +
  geom_boxplot(outlier.shape = NA) +
  labs(x = "Week", y = "Landings (lbs)",
       title = "RI weekly BSB landings — distribution by week") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6))
print(p6)
