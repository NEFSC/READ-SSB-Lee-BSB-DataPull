# =============================================================================
# Script:  bsb_exploratory.R
# Purpose: Main exploratory analysis of BSB commercial landings.  Applies gear
#          and market category cleaning, flags questionable VA/DE records,
#          merges quarterly CPI deflator, and produces price distributions,
#          market composition charts, gear charts, and price-over-time series.
# Inputs:  data_folder/main/commercial/landings_all_{in_string}.Rds
#          data_folder/main/commercial/cams_gears_{in_string}.Rds
#          data_folder/external/deflatorsQ_{in_string}.Rds
# Outputs: images/exploratory/price_histograms.png
#          images/exploratory/wprice_histograms.png
#          images/exploratory/wprice_histograms_vertical.png
#          images/exploratory/vio_grades.png
#          images/exploratory/price_box{year}.png   (one per year)
#          images/exploratory/Wprice_box{year}.png  (one per year, weighted)
#          images/exploratory/market_cats_within_year.png
#          images/exploratory/fmarket_cats_within_year.png
#          images/exploratory/market_cats_over_time.png
#          images/exploratory/fmarket_cats_over_time.png
#          images/exploratory/market_cats_over_2018.png
#          images/exploratory/fmarket_cats_over_2018.png
#          images/exploratory/questionable2020.png
#          images/exploratory/fquestionable2020.png
#          images/exploratory/market_cats_by_state.png
#          images/exploratory/fmarket_cats_by_state.png
#          images/exploratory/market_cats_{state}.png  (one per state)
#          images/exploratory/fmarket_cats_{state}.png (one per state)
#          images/exploratory/gears_by_year.png
#          images/exploratory/fgears_by_year.png
#          images/exploratory/price_overtime_{state}.png  (one per state)
#          images/exploratory/priceR_overtime_{state}.png (one per state)
#          images/exploratory/price_overstate_{mkt}.png   (one per market cat)
#          images/exploratory/priceR_overstate_{mkt}.png  (one per market cat)
# Notes:   Ported from stata_code/analysis/bsb_exploratory.do
#          in_string must be set before sourcing (via wrapper or manually).
#          Stata's xi i.market_desc*lndlb interaction (QJumbo etc.) computes
#          market-level daily quantities; these variables (ownQ, largerQ,
#          smallerQ) are never referenced in any export command in the Stata
#          script and are omitted here.
#          valueR in Stata = valueR_CPI in R (confirmed by domain expert).
# Author:
# Date:
# =============================================================================


source(here("R_code", "analysis", "helpers", "gear_market_helpers.R"))

if (!exists("in_string")) {
  stop("'in_string' not defined. Run via 00_exploratory_analysis_wrapper.R or set in_string manually.")
}


exclude_states <- c("CN", "FL", "ME", "NH", "PA", "SC")


# =============================================================================
# Section 1: Load and initial cleaning
# =============================================================================

landings_raw <- readRDS(
  here("data_folder", "main", "commercial", glue("landings_all_{in_string}.Rds"))
)
cams_gears <- readRDS(
  here("data_folder", "main", "commercial", glue("cams_gears_{in_string}.Rds"))
)
deflators_q <- readRDS(
  here("data_folder", "external", glue("deflatorsQ_{in_string}.Rds"))
)

landings <- landings_raw %>%
  filter(merge_species_codes != 1) %>%
  mutate(
    dlr_date = as.Date(dlr_date),
    dateq    = paste0(year(dlr_date), "Q", quarter(dlr_date)),
    day      = day(dlr_date),

    # Questionable-status flag: VA and DE records with unusual PZERO patterns
    questionable_status = case_when(
      status == "PZERO" & state == "VA" &
        dlr_cflic %in% c("2147", "1148") & year >= 2021        ~ 1L,
      status == "PZERO" & state == "DE" & day == 1 & price == 0 ~ 1L,
      status == "PZERO" & state == "DE" & day == 1 & port == 80999 ~ 1L,
      TRUE ~ 0L
    )
  )


# =============================================================================
# Section 2: Merge gear codes and apply gear category mapping
# =============================================================================

# Stata: merge m:1 negear using cams_gears; assert _merge==3
landings <- landings %>%
  left_join(cams_gears, by = "negear") %>%
  apply_gear_categories()

stopifnot(sum(is.na(landings$mygear)) == 0)  # assert _merge==3


# =============================================================================
# Section 3: Market and grade rebinning; state as character (no encoding needed)
# =============================================================================

landings <- landings %>%
  apply_market_rebinning() %>%
  apply_grade_cleaning() %>%
  mutate(
    # Short grade label for violin plot axis
    mygrade_short = case_when(
      grade_desc == "Round"   ~ "R",
      grade_desc == "Live"    ~ "L",
      grade_desc == "Ungraded" ~ "U",
      TRUE ~ NA_character_
    )
  )


# =============================================================================
# Section 4: Collapse to transaction level and merge deflator
# Stata: collapse (sum) value lndlb livlb, by(camsid hullid mygear ... status questionable_status)
# =============================================================================

landings_txn <- landings %>%
  group_by(camsid, hullid, mygear, record_sail, record_land,
           dlr_date, dlrid, state, grade_desc, market_desc, dateq,
           year, month, area, status, questionable_status) %>%
  summarise(
    value  = sum(value,  na.rm = TRUE),
    lndlb  = sum(lndlb,  na.rm = TRUE),
    livlb  = sum(livlb,  na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    price     = if_else(lndlb > 0, value / lndlb, NA_real_),
    weighting = lndlb   # clonevar weighting=lndlb (used as freq weight in histograms)
  )

# Merge quarterly deflator
# NOTE: unmatched rows (no CPI yet) are current-year months >= May; drop them.
deflators_join <- deflators_q %>%
  select(dateq = quarter, fCPIAUCSL_2023Q1)

landings_txn <- landings_txn %>%
  left_join(deflators_join, by = "dateq")

unmatched <- is.na(landings_txn$fCPIAUCSL_2023Q1)
if (any(unmatched)) {
  stopifnot(all(
    landings_txn$year[unmatched]  == max(landings_txn$year) &
    landings_txn$month[unmatched] >= 5
  ))
  landings_txn <- landings_txn %>% filter(!unmatched)
}

landings_txn <- landings_txn %>%
  mutate(
    priceR_CPI  = price  / fCPIAUCSL_2023Q1,  # real 2023Q1 CPI-U dollars
    valueR_CPI  = value  / fCPIAUCSL_2023Q1,
    lndlb_000s  = lndlb  / 1000               # label var lndlb "landings 000s"
  )

# Apply analysis filters (Stata: replace keep=0 if inlist(state,...); keep=0 if price>=15)
landings_filt <- landings_txn %>%
  filter(!state %in% exclude_states, price < 15)


# =============================================================================
# Section 5: Price histograms (unweighted and frequency-weighted)
# =============================================================================

# Per-category unweighted + weighted histograms (combined via facet_wrap)
# Stata: foreach l ... hist priceR_CPI ... ; graph combine ...
p_hist_unw <- landings_filt %>%
  filter(priceR_CPI <= 10) %>%
  ggplot(aes(x = priceR_CPI)) +
  geom_histogram(binwidth = 0.25, fill = "steelblue", color = "white") +
  facet_wrap(~ market_desc) +
  labs(x = "Real price (2023Q1 $)", y = "Fraction", title = "Price distribution by market category") +
  scale_x_continuous(breaks = 0:10) +
  theme_bw()

ggsave(file.path(img_dir, "price_histograms.png"),
       plot = p_hist_unw, width = 10, height = 8, dpi = 150)
message("Saved: price_histograms.png")

# Frequency-weighted (Stata: [fweight=weighting])
p_hist_w <- landings_filt %>%
  filter(priceR_CPI <= 10) %>%
  ggplot(aes(x = priceR_CPI, weight = weighting)) +
  geom_histogram(binwidth = 0.25, fill = "steelblue", color = "white") +
  facet_wrap(~ market_desc) +
  labs(x = "Real price (2023Q1 $)", y = "Fraction (weighted by lbs)",
       title = "Price distribution by market category (lbs-weighted)") +
  scale_x_continuous(breaks = 0:10) +
  theme_bw()

ggsave(file.path(img_dir, "wprice_histograms.png"),
       plot = p_hist_w, width = 10, height = 8, dpi = 150)
message("Saved: wprice_histograms.png")

# Vertical layout: one facet column (Stata: graph combine ... cols(1) xcommon)
p_hist_v <- landings_filt %>%
  filter(priceR_CPI <= 10) %>%
  ggplot(aes(x = priceR_CPI, weight = weighting)) +
  geom_histogram(binwidth = 0.25, fill = "steelblue", color = "white") +
  facet_wrap(~ market_desc, ncol = 1) +
  labs(x = "Real price (2023Q1 $)", y = "Fraction (weighted)",
       title = "Price distributions — vertical") +
  scale_x_continuous(breaks = 0:10) +
  theme_bw()

ggsave(file.path(img_dir, "wprice_histograms_vertical.png"),
       plot = p_hist_v, width = 5, height = 14, dpi = 150)
message("Saved: wprice_histograms_vertical.png")


# =============================================================================
# Section 6: Violin plot by grade × market category
# Stata: vioplot priceR_CPI if priceR_CPI<=10, over(mygrade_short) over(market_desc)
# =============================================================================

p_vio <- landings_filt %>%
  filter(priceR_CPI <= 10, !is.na(mygrade_short)) %>%
  ggplot(aes(x = market_desc, y = priceR_CPI, fill = mygrade_short)) +
  geom_violin(scale = "width", alpha = 0.7) +
  labs(x = "Market category", y = "Real price (2023Q1 $)",
       fill = "Grade", title = "Price distribution by grade and market category") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(file.path(img_dir, "vio_grades.png"),
       plot = p_vio, width = 10, height = 6, dpi = 150)
message("Saved: vio_grades.png")


# =============================================================================
# Section 7: Box plots by year (unweighted and weighted)
# Stata: foreach y ... graph box priceR_CPI if year==`y' ...
# NOTE: market_desc!=5 in Stata excludes Extra Small (level 5 in Stata encoding;
# after rebinning Extra Small is empty, so this filter has no effect here).
# =============================================================================

walk(sort(unique(landings_filt$year)), function(y) {
  yr_data <- landings_filt %>%
    filter(year == y, priceR_CPI <= 10, market_desc != "Extra Small")

  p_box <- ggplot(yr_data, aes(x = grade_desc, y = priceR_CPI)) +
    geom_boxplot(outlier.shape = NA) +
    facet_wrap(~ market_desc, scales = "free_x") +
    labs(x = "Grade", y = "Real price (2023Q1 $)",
         title = glue("{y} price distribution by market category and grade")) +
    coord_cartesian(ylim = c(0, 10)) +
    theme_bw(base_size = 9) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  ggsave(file.path(img_dir, glue("price_box{y}.png")),
         plot = p_box, width = 10, height = 6, dpi = 150)

  # Weighted version (Stata: [fweight=weighting] — ggplot2 uses size or weight aes)
  p_wbox <- ggplot(yr_data, aes(x = grade_desc, y = priceR_CPI, weight = weighting)) +
    geom_boxplot(outlier.shape = NA) +
    facet_wrap(~ market_desc, scales = "free_x") +
    labs(x = "Grade", y = "Real price (2023Q1 $)",
         title = glue("{y} price distribution (lbs-weighted)")) +
    coord_cartesian(ylim = c(0, 10)) +
    theme_bw(base_size = 9) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  ggsave(file.path(img_dir, glue("Wprice_box{y}.png")),
         plot = p_wbox, width = 10, height = 6, dpi = 150)
})
message(glue("Saved: price_box and Wprice_box for {n_distinct(landings_filt$year)} years"))


# =============================================================================
# Section 8: Market composition within year (by month)
# Stata: preserve; collapse (sum) lndlb value, by(month market_desc); graph bar
# =============================================================================

by_month <- landings_txn %>%
  group_by(month, market_desc) %>%
  summarise(lndlb = sum(lndlb_000s, na.rm = TRUE),
            value = sum(value,      na.rm = TRUE), .groups = "drop") %>%
  group_by(month) %>%
  mutate(frac = lndlb / sum(lndlb)) %>%
  ungroup()

p_mkt_month <- ggplot(by_month, aes(x = factor(month), y = lndlb, fill = market_desc)) +
  geom_col() +
  labs(x = "Month", y = "Landings (000s lbs)", fill = "Market cat",
       title = "Market category composition by month") +
  theme_bw()
ggsave(file.path(img_dir, "market_cats_within_year.png"),
       plot = p_mkt_month, width = 10, height = 6, dpi = 150)
message("Saved: market_cats_within_year.png")

p_fmkt_month <- ggplot(by_month, aes(x = factor(month), y = frac, fill = market_desc)) +
  geom_col() +
  labs(x = "Month", y = "Fraction", fill = "Market cat",
       title = "Market category fraction by month") +
  theme_bw()
ggsave(file.path(img_dir, "fmarket_cats_within_year.png"),
       plot = p_fmkt_month, width = 10, height = 6, dpi = 150)
message("Saved: fmarket_cats_within_year.png")


# =============================================================================
# Section 9: Market composition over time
# =============================================================================

by_year_mkt <- landings_txn %>%
  group_by(year, market_desc) %>%
  summarise(lndlb = sum(lndlb_000s, na.rm = TRUE),
            value = sum(value,      na.rm = TRUE), .groups = "drop") %>%
  group_by(year) %>%
  mutate(frac = lndlb / sum(lndlb)) %>%
  ungroup()

p_mkt_yr <- ggplot(by_year_mkt,
                   aes(x = factor(year), y = lndlb, fill = market_desc)) +
  geom_col() +
  labs(x = "Year", y = "Landings (000s lbs)", fill = "Market cat",
       title = "Market category composition over time") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(img_dir, "market_cats_over_time.png"),
       plot = p_mkt_yr, width = 12, height = 6, dpi = 150)
message("Saved: market_cats_over_time.png")

p_fmkt_yr <- ggplot(by_year_mkt,
                    aes(x = factor(year), y = frac, fill = market_desc)) +
  geom_col() +
  labs(x = "Year", y = "Fraction", fill = "Market cat",
       title = "Market category fraction over time") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(img_dir, "fmarket_cats_over_time.png"),
       plot = p_fmkt_yr, width = 12, height = 6, dpi = 150)
message("Saved: fmarket_cats_over_time.png")

# 2018-present zoom
p_mkt_2018 <- by_year_mkt %>%
  filter(year >= 2018) %>%
  ggplot(aes(x = factor(year), y = lndlb, fill = market_desc)) +
  geom_col() +
  labs(x = "Year", y = "Landings (000s lbs)", fill = "Market cat",
       title = "Market category composition 2018-present") +
  theme_bw()
ggsave(file.path(img_dir, "market_cats_over_2018.png"),
       plot = p_mkt_2018, width = 8, height = 5, dpi = 150)
message("Saved: market_cats_over_2018.png")

p_fmkt_2018 <- by_year_mkt %>%
  filter(year >= 2018) %>%
  ggplot(aes(x = factor(year), y = frac, fill = market_desc)) +
  geom_col() +
  labs(x = "Year", y = "Fraction", fill = "Market cat",
       title = "Market category fraction 2018-present") +
  theme_bw()
ggsave(file.path(img_dir, "fmarket_cats_over_2018.png"),
       plot = p_fmkt_2018, width = 8, height = 5, dpi = 150)
message("Saved: fmarket_cats_over_2018.png")


# =============================================================================
# Section 10: Questionable landings 2020-2023
# =============================================================================

by_mkt_q <- landings_txn %>%
  filter(year >= 2020, year <= 2023) %>%
  group_by(market_desc, questionable_status) %>%
  summarise(lndlb = sum(lndlb_000s, na.rm = TRUE),
            value = sum(value,      na.rm = TRUE), .groups = "drop") %>%
  group_by(market_desc) %>%
  mutate(frac = lndlb / sum(lndlb)) %>%
  ungroup()

p_q <- ggplot(by_mkt_q,
              aes(x = market_desc, y = lndlb, fill = factor(questionable_status))) +
  geom_col() +
  labs(x = "Market category", y = "Landings (000s lbs)",
       fill = "Questionable", title = "Questionable landings by market category (2020-2023)") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(file.path(img_dir, "questionable2020.png"),
       plot = p_q, width = 8, height = 5, dpi = 150)
message("Saved: questionable2020.png")

p_fq <- ggplot(by_mkt_q,
               aes(x = market_desc, y = frac, fill = factor(questionable_status))) +
  geom_col() +
  labs(x = "Market category", y = "Fraction",
       fill = "Questionable", title = "Fraction questionable by market category (2020-2023)") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(file.path(img_dir, "fquestionable2020.png"),
       plot = p_fq, width = 8, height = 5, dpi = 150)
message("Saved: fquestionable2020.png")


# =============================================================================
# Section 11: Market composition by state
# =============================================================================

by_state_mkt <- landings_txn %>%
  filter(!state %in% exclude_states) %>%
  group_by(state, market_desc) %>%
  summarise(lndlb = sum(lndlb_000s, na.rm = TRUE), .groups = "drop") %>%
  group_by(state) %>%
  mutate(frac = lndlb / sum(lndlb)) %>%
  ungroup()

p_mkt_st <- ggplot(by_state_mkt, aes(x = state, y = lndlb, fill = market_desc)) +
  geom_col() +
  labs(x = "State", y = "Landings (000s lbs)", fill = "Market cat",
       title = "Market category composition by state") +
  theme_bw()
ggsave(file.path(img_dir, "market_cats_by_state.png"),
       plot = p_mkt_st, width = 10, height = 6, dpi = 150)
message("Saved: market_cats_by_state.png")

p_fmkt_st <- ggplot(by_state_mkt, aes(x = state, y = frac, fill = market_desc)) +
  geom_col() +
  labs(x = "State", y = "Fraction", fill = "Market cat",
       title = "Market category fraction by state") +
  theme_bw()
ggsave(file.path(img_dir, "fmarket_cats_by_state.png"),
       plot = p_fmkt_st, width = 10, height = 6, dpi = 150)
message("Saved: fmarket_cats_by_state.png")


# =============================================================================
# Section 12: Per-state market composition over time
# Stata: foreach l ... graph bar (asis) frac ... state=="`l'" / lndlb
# =============================================================================

by_state_yr_mkt <- landings_txn %>%
  filter(!state %in% exclude_states) %>%
  group_by(year, state, market_desc) %>%
  summarise(lndlb = sum(lndlb_000s, na.rm = TRUE), .groups = "drop") %>%
  group_by(year, state) %>%
  mutate(frac = lndlb / sum(lndlb)) %>%
  ungroup()

walk(sort(unique(by_state_yr_mkt$state)), function(st) {
  st_data <- filter(by_state_yr_mkt, state == st)

  p_l <- ggplot(st_data, aes(x = factor(year), y = lndlb, fill = market_desc)) +
    geom_col() +
    labs(x = "Year", y = "Landings (000s lbs)", fill = "Market cat",
         title = glue("Size composition in {st}")) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  ggsave(file.path(img_dir, glue("market_cats_{st}.png")),
         plot = p_l, width = 10, height = 6, dpi = 150)

  p_f <- ggplot(st_data, aes(x = factor(year), y = frac, fill = market_desc)) +
    geom_col() +
    labs(x = "Year", y = "Fraction", fill = "Market cat",
         title = glue("Size composition fraction in {st}")) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  ggsave(file.path(img_dir, glue("fmarket_cats_{st}.png")),
         plot = p_f, width = 10, height = 6, dpi = 150)
})
message(glue("Saved per-state market composition charts"))


# =============================================================================
# Section 13: Gear composition by year
# =============================================================================

by_yr_gear <- landings_txn %>%
  filter(!state %in% exclude_states) %>%
  group_by(year, mygear) %>%
  summarise(lndlb = sum(lndlb_000s, na.rm = TRUE), .groups = "drop") %>%
  group_by(year) %>%
  mutate(frac = lndlb / sum(lndlb)) %>%
  ungroup()

p_gear_yr <- ggplot(by_yr_gear, aes(x = factor(year), y = lndlb, fill = mygear)) +
  geom_col() +
  labs(x = "Year", y = "Landings (000s lbs)", fill = "Gear",
       title = "Gear composition by year") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(img_dir, "gears_by_year.png"),
       plot = p_gear_yr, width = 12, height = 6, dpi = 150)
message("Saved: gears_by_year.png")

p_fgear_yr <- ggplot(by_yr_gear, aes(x = factor(year), y = frac, fill = mygear)) +
  geom_col() +
  labs(x = "Year", y = "Fraction", fill = "Gear",
       title = "Gear fraction by year") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(img_dir, "fgears_by_year.png"),
       plot = p_fgear_yr, width = 12, height = 6, dpi = 150)
message("Saved: fgears_by_year.png")


# =============================================================================
# Section 14: Price time series by state
# Stata: collapse (sum) lndlb value valueR, by(state market_desc year);
#        foreach l: tsset market_desc year; xtline price/priceR_CPI, overlay
# valueR in Stata = valueR_CPI in R (confirmed by domain expert)
# =============================================================================

price_state_yr <- landings_txn %>%
  filter(!state %in% exclude_states) %>%
  group_by(state, market_desc, year) %>%
  summarise(
    lndlb     = sum(lndlb_000s, na.rm = TRUE),
    value     = sum(value,      na.rm = TRUE),
    valueR_CPI = sum(valueR_CPI, na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  mutate(
    price      = if_else(lndlb > 0, value     / (lndlb * 1000), NA_real_),
    priceR_CPI = if_else(lndlb > 0, valueR_CPI / (lndlb * 1000), NA_real_)
  )

# Per-state price over time (xtline, overlay = all market cats on one plot)
walk(sort(unique(price_state_yr$state)), function(st) {
  st_data <- price_state_yr %>%
    filter(state == st, market_desc %in% c("Jumbo","Large","Medium","Small"))

  p_pr <- ggplot(st_data %>% filter(price <= 6),
                 aes(x = year, y = price, color = market_desc)) +
    geom_line() +
    labs(x = "Year", y = "Nominal price ($/lb)", color = "Market cat",
         title = glue("{st} — price by market category")) +
    scale_x_continuous(breaks = seq(2010, 2025, 5),
                       minor_breaks = seq(2010, 2025, 1)) +
    theme_bw()
  ggsave(file.path(img_dir, glue("price_overtime_{st}.png")),
         plot = p_pr, width = 8, height = 5, dpi = 150)

  p_pR <- ggplot(st_data %>% filter(priceR_CPI <= 6),
                 aes(x = year, y = priceR_CPI, color = market_desc)) +
    geom_line() +
    labs(x = "Year", y = "Real price (2023Q1 $/lb)", color = "Market cat",
         title = glue("{st} — real price by market category")) +
    scale_x_continuous(breaks = seq(2010, 2025, 5),
                       minor_breaks = seq(2010, 2025, 1)) +
    theme_bw()
  ggsave(file.path(img_dir, glue("priceR_overtime_{st}.png")),
         plot = p_pR, width = 8, height = 5, dpi = 150)
})
message("Saved per-state price series")


# =============================================================================
# Section 15: Price time series by market category across states
# Stata: collapse ..., by(state market_desc year);
#        foreach l ... tsset state year; xtline price/priceR, overlay
# =============================================================================

price_mkt_yr <- price_state_yr  # same data, just looping by market_desc

walk(levels(price_mkt_yr$market_desc), function(mkt) {
  mkt_data <- price_mkt_yr %>% filter(as.character(market_desc) == mkt)

  p_pr <- ggplot(mkt_data,
                 aes(x = year, y = price, color = state)) +
    geom_line() +
    labs(x = "Year", y = "Nominal price ($/lb)", color = "State",
         title = glue("{mkt} — price over time by state")) +
    scale_x_continuous(breaks = seq(2010, 2025, 5),
                       minor_breaks = seq(2010, 2025, 1)) +
    theme_bw() +
    theme(legend.position = "right")
  ggsave(file.path(img_dir, glue("price_overstate_{mkt}.png")),
         plot = p_pr, width = 9, height = 5, dpi = 150)

  p_pR <- ggplot(mkt_data,
                 aes(x = year, y = priceR_CPI, color = state)) +
    geom_line() +
    labs(x = "Year", y = "Real price (2023Q1 $/lb)", color = "State",
         title = glue("{mkt} — real price over time by state")) +
    scale_x_continuous(breaks = seq(2010, 2025, 5),
                       minor_breaks = seq(2010, 2025, 1)) +
    theme_bw() +
    theme(legend.position = "right")
  ggsave(file.path(img_dir, glue("priceR_overstate_{mkt}.png")),
         plot = p_pR, width = 9, height = 5, dpi = 150)
})
message("Saved per-market-category price series")
