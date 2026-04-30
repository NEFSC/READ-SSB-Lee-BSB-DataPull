# =============================================================================
# Script:  bsb_exploratory_dealers.R
# Purpose: Dealer-focused exploratory analysis of BSB landings.  Identifies
#          which dealers report the highest share of unclassified BSB landings;
#          examines how unclassified status varies by market category over time.
#          Display-only: no graphs are exported (consistent with Stata original).
# Inputs:  data_folder/main/commercial/landings_all_{in_string}.Rds
#          data_folder/main/commercial/cams_gears_{in_string}.Rds
#          data_folder/main/commercial/dealers_annual_{in_string}.Rds
# Outputs: None — results printed to console (exploratory use only)
# Notes:   Ported from stata_code/analysis/bsb_exploratory_dealers.do
#          in_string must be set before sourcing (via wrapper or manually).
#          Market rebinning rule differs from bsb_exploratory.R:
#            PW (Pee Wee) stays as ES (Extra Small), not merged into SQ (Small).
#          Stata's browse commands translated to print(head(...)) and
#          print(arrange(...)) for console inspection.
# =============================================================================

source(here("R_code", "analysis", "helpers", "gear_market_helpers.R"))

if (!exists("in_string")) {
  stop("'in_string' not defined. Run via 00_exploratory_analysis_wrapper.R or set in_string manually.")
}


# =============================================================================
# Section 1: Load, clean, merge gears, apply dealers market rebinning
# =============================================================================

landings_raw <- readRDS(
  here("data_folder", "main", "commercial", glue("landings_all_{in_string}.Rds"))
)
cams_gears <- readRDS(
  here("data_folder", "main", "commercial", glue("cams_gears_{in_string}.Rds"))
)
dealers_annual <- readRDS(
  here("data_folder", "main", "commercial", glue("dealers_annual_{in_string}.Rds"))
)

landings <- landings_raw %>%
  filter(merge_species_codes != 1) %>%
  mutate(
    dlr_date = as.Date(dlr_date),
    dateq    = paste0(lubridate::year(dlr_date), "Q", lubridate::quarter(dlr_date))
  ) %>%
  left_join(cams_gears, by = "negear") %>%
  apply_gear_categories() %>%
  # NOTE: dealers variant — PW stays as ES (not merged to SQ like in bsb_exploratory.R)
  apply_market_rebinning_dealers() %>%
  mutate(
    mym = factor(market_desc,
                 levels = c("JUMBO", "LARGE", "MEDIUM", "SMALL",
                            "EXTRA SMALL", "UNCLASSIFIED"))
  )


# =============================================================================
# Section 2: Collapse to dealer × year × market category; merge dealer names
# Stata: collapse (sum) lndlb, by(dlrid year market_desc)
#        merge m:1 dnum year using dealers_annual
# =============================================================================

dealer_mkt <- landings %>%
  group_by(dlrid, year, mym) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop")

dealer_mkt<-dealer_mkt %>%
  mutate(dlrid=as.numeric(dlrid))

# Stata: rename dlrid dnum; merge; rename dnum dlrid
dealer_mkt <- dealer_mkt %>%
  left_join(dealers_annual %>% rename(dlrid = dnum), by = c("dlrid", "year"))

# dealers_annual has some 'gaps' in it, sometimes a dealer has a permit in year 1 and 3, but not year 3. 
# this causes the dealer's demographics to be missing, including dlr_name 

# Pivot wide: one lndlb column per market category (reshape wide lndlb, j(mym))
dealer_wide <- dealer_mkt %>%
  pivot_wider(
    names_from  = mym,
    values_from = lndlb,
    values_fill = 0
  )

# Stata: foreach var of varlist lndlb*: replace var=0 if var==.
# (pivot_wider values_fill handles this)

# Stata: egen total=rowtotal(lndlb1-lndlb6)
dealer_wide <- dealer_wide %>%
  mutate(
    total = rowSums(
      select(., any_of(c("JUMBO", "LARGE", "MEDIUM", "SMALL",
                         "EXTRA SMALL", "UNCLASSIFIED"))),
      na.rm = TRUE
    ),
    unclassified_frac = if_else(total > 0, UNCLASSIFIED / total, NA_real_)
  )

# Yearly totals for comparison
yearly_unc <- dealer_wide %>%
  group_by(year) %>%
  summarise(
    t6 = sum(UNCLASSIFIED, na.rm = TRUE),
    tt = sum(total,        na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(yearly_unc = t6 / tt)

dealer_wide <- dealer_wide %>%
  left_join(yearly_unc %>% select(year, yearly_unc), by = "year")

# Stata: gen f6 = lndlb6/t6 (share of total yearly unclassified from this dealer)
dealer_wide <- dealer_wide %>%
  left_join(yearly_unc %>% select(year, t6), by = "year") %>%
  mutate(f6 = if_else(t6 > 0, UNCLASSIFIED / t6, NA_real_))

# Rank dealers by share of unclassified (frank: highest f6 = rank 1)
dealer_ranked <- dealer_wide %>%
  group_by(year) %>%
  mutate(frank = rank(-f6, ties.method = "first")) %>%
  ungroup()

# Stata: browse if year>=2010 & frank<=5  → print top dealers by unclassified share
cat("\n=== Top 5 dealers by share of yearly unclassified landings (2010+) ===\n")
print(
  dealer_ranked %>%
    filter(year >= 2010, frank <= 5) %>%
    arrange(year, frank) %>%
    select(year, dlrid, any_of(c("dlr_name")), yearly_unc, unclassified_frac,
           UNCLASSIFIED, f6, t6, frank)
)

# Stata: browse if unclassified_frac > yearly_unc & year>=2010
cat("\n=== Dealers with above-average unclassified fraction (2010+) ===\n")
print(
  dealer_wide %>%
    filter(year >= 2010, unclassified_frac > yearly_unc) %>%
    arrange(year, desc(unclassified_frac)) %>%
    select(year, dlrid, any_of(c("dlr_name")), yearly_unc, unclassified_frac)
)


# =============================================================================
# Section 3: Simpler analysis — unclassified landings by status and market code
# (Second use of landings_all in the Stata script)
# =============================================================================

landings2 <- landings_raw %>%
  filter(merge_species_codes != 1) %>%
  mutate(
    dlr_date = as.Date(dlr_date),
    dateq    = paste0(lubridate::year(dlr_date), "Q", lubridate::quarter(dlr_date)),
    # Simpler market rebinning used in second section of the Stata script
    market_desc = if_else(market_desc == "MIXED OR UNSIZED", "UNCLASSIFIED", market_desc),
    market_code = if_else(market_code == "MX", "UN", market_code),
    market_desc = if_else(market_desc == "MEDIUM OR SELECT", "MEDIUM", market_desc),
    market_desc = if_else(market_desc == "PEE WEE (RATS)", "EXTRA SMALL", market_desc),
    market_code = if_else(market_code == "PW", "ES", market_code),
    mym = factor(market_desc,
                 levels = c("JUMBO", "LARGE", "MEDIUM", "SMALL",
                            "EXTRA SMALL", "UNCLASSIFIED"))
  )

# Stata: collapse (sum) lndlb, by(year mym status)
unclass_by_status <- landings2 %>%
  group_by(year, mym, status) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop")

# Stata: browse if mym==6 (UNCLASSIFIED)
cat("\n=== Unclassified landings by year and status ===\n")
print(
  unclass_by_status %>%
    filter(as.character(mym) == "UNCLASSIFIED") %>%
    arrange(year, status)
)
