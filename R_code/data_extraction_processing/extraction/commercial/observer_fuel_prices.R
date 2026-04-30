# =============================================================================
# Script:  observer_fuel_prices.R
# Purpose: Pull observed fuel prices from the observer trip database and
#          compute monthly average fuel prices by state (simple and
#          fuel-quantity-weighted).
# Inputs:  Oracle: obtrp (observer trips), port (port reference table)
# Outputs: data_folder/raw/raw_fuel_prices_{vintage_string}.Rds
#            Row-level fuel price observations (NK state dropped).
#          data_folder/main/monthly_state_fuelprices_{vintage_string}.Rds
#            Monthly simple-mean and quantity-weighted-mean fuel prices by state.
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/observer_fuel_prices.do
#          "NK" is an unrecognized state code; dropped before aggregation.
#          Output paths do not include a commercial/ subfolder, matching Stata.
# =============================================================================


# SQL uses an implicit join (comma syntax) between obtrp and port tables.
# Filters: year >= 2004; fuelprice not null; port codes must match.
fuel_query <- glue(
  "select ob.datesail, ob.port, ob.fuelgal, ob.fuelprice,
          po.portnm, po.stateabb, po.county
   from obtrp ob, port po
   where year >= 2004
     and fuelprice is not null
     and po.port = ob.port"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

fuel_raw <- dbGetQuery(nova_conn, fuel_query)

dbDisconnect(nova_conn)


fuel_raw <- fuel_raw %>%
  rename_with(tolower) %>%
  # Oracle DATE arrives as POSIXct; convert to Date.
  # Stata: replace datesail = dofc(datesail)
  mutate(datesail = as.Date(datesail)) %>%
  # "NK" is an unrecognized state abbreviation; drop before any analysis.
  filter(stateabb != "NK")

# Save raw observations
raw_path <- here("data_folder", "raw",
                 glue("raw_fuel_prices_{vintage_string}.Rds"))
if (!dir.exists(dirname(raw_path))) dir.create(dirname(raw_path), recursive = TRUE)
saveRDS(fuel_raw, file = raw_path)
message(glue("Saved: {raw_path}"))

# Drop records with missing fuelgal before computing aggregates.
# Stata: drop if fuelgal == .
fuel_clean <- fuel_raw %>%
  filter(!is.na(fuelgal)) %>%
  # monthly = first day of the month containing datesail
  # Stata: gen monthly = mofd(datesail)  (monthly date serial)
  mutate(monthly = floor_date(datesail, "month"))


# =============================================================================
# Two aggregations, then joined — mirrors Stata preserve/restore pattern
# =============================================================================

# Aggregation A: quantity-weighted mean fuel price by state-month.
# Stata: collapse (mean) wfuelprice=fuelprice [fweight=fuelgal], by(stateabb monthly)
# fweight treats fuelgal as frequency weights; equivalent to weighted.mean().
# NOTE: weighted.mean() is valid for continuous weights too, but Stata fweight
# requires integer values — verify fuelgal is integer if strict equivalence needed.
agg_weighted <- fuel_clean %>%
  group_by(stateabb, monthly) %>%
  summarise(
    wfuelprice = weighted.mean(fuelprice, w = fuelgal),
    .groups    = "drop"
  )

# Aggregation B: simple mean, total gallons, observation count by state-month.
# Stata: collapse (mean) fuelprice (sum) fuelgal (count) nobs=fuelgal, by(stateabb monthly)
agg_simple <- fuel_clean %>%
  group_by(stateabb, monthly) %>%
  summarise(
    fuelprice = mean(fuelprice),
    fuelgal   = sum(fuelgal),
    nobs      = n(),            # count of non-missing fuelgal rows
    .groups   = "drop"
  )

# Join the two aggregations.
# Stata: merge 1:1 stateabb monthly using t1; assert _merge==3
nrow_a <- nrow(agg_simple)
monthly_prices <- agg_simple %>%
  left_join(agg_weighted, by = join_by(stateabb, monthly))

stopifnot(
  "Weighted and simple aggregations have different state-month combinations" =
    nrow(monthly_prices) == nrow_a,
  "Some state-months missing wfuelprice after join" =
    sum(is.na(monthly_prices$wfuelprice)) == 0
)

agg_path <- here("data_folder", "main",
                 glue("monthly_state_fuelprices_{vintage_string}.Rds"))
if (!dir.exists(dirname(agg_path))) dir.create(dirname(agg_path), recursive = TRUE)
saveRDS(monthly_prices, file = agg_path)
message(glue("Saved: {agg_path}"))
