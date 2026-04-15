# =============================================================================
# Script:  permit_characteristics_extractions.R
# Purpose: (1) Build a permit-fishing_year panel of which fishing plan/category
#          combinations each permit held in each year (permit_working).
#          (2) Build a permit-fishing_year panel of vessel physical characteristics
#          (permit_portfolio).
#          (3) Extract lobster trap limit by hull and year (lobster_traps).
# Inputs:  Oracle: nefsc_garfo.permit_vps_fishery_ner (permit plan/category records)
#                  nefsc_garfo.permit_vps_vessel (vessel characteristics records)
# Outputs: data_folder/main/commercial/vps_fishery_raw_{vintage_string}.Rds
#          data_folder/main/commercial/permit_working_{vintage_string}.Rds
#          data_folder/main/commercial/permit_portfolio_{vintage_string}.Rds
#          data_folder/main/commercial/lobster_traps_{vintage_string}.Rds
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/permit_characteristics_extractions.do
#          Fishing year j runs May 1 of year j through April 30 of year j+1.
#          The Stata original saves permit_working to data_main but reads it
#          back from data_raw — a path bug.  R port uses data_main throughout.
# Author:
# Date:
# =============================================================================

library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)

here::i_am("R_code/data_extraction_processing/extraction/commercial/permit_characteristics_extractions.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())

# Update last_yr each year to extend the extraction range.
last_yr      <- 2025
fishing_years <- 1996:last_yr

output_dir <- here("data_folder", "main", "commercial")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)


# =============================================================================
# Chunk 1: Pull permit fishery records, clean dates, save raw file
# =============================================================================

fishery_query <- glue(
  "select vp.ap_year, vp.ap_num, vp.vp_num, vp.plan, vp.cat,
          vp.start_date, vp.end_date, vp.date_expired, vp.date_canceled
   from nefsc_garfo.permit_vps_fishery_ner vp
   where ap_year between 1996 and {last_yr}
   order by vp_num, ap_num"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)
fishery_raw <- dbGetQuery(nova_conn, fishery_query)
dbDisconnect(nova_conn)

fishery_raw <- fishery_raw %>%
  rename_with(tolower) %>%
  # Oracle DATE columns arrive as POSIXct via ROracle; convert to Date.
  # Stata: gen mys = dofc(start_date), etc.
  mutate(across(c(start_date, end_date, date_expired, date_canceled), as.Date))

# myde = effective end of permit = earliest non-missing of the three end dates.
# Stata: gen myde = min(end_date, date_expired, date_canceled)
# pmin(..., na.rm = TRUE) matches Stata's min() which ignores missing values.
# When all three are NA, pmin returns NA — matching Stata's missing (.) result.
fishery_raw <- fishery_raw %>%
  mutate(myde = pmin(end_date, date_expired, date_canceled, na.rm = TRUE))

# Drop records where permit start is on or after its effective end date.
# Stata: drop if start_date >= myde
# Stata treats missing (.) as +Inf, so start_date >= . is FALSE → rows with
# missing myde are kept.  R equivalent: keep if myde is NA OR start_date < myde.
# NOTE: the second condition in Stata (| start_date >= myde) is identical to
# the first — a copy-paste artifact; omitted in R.
fishery_raw <- fishery_raw %>%
  filter(is.na(myde) | start_date < myde)

saveRDS(fishery_raw,
        file.path(output_dir, glue("vps_fishery_raw_{vintage_string}.Rds")))
message(glue("Saved: vps_fishery_raw_{vintage_string}.Rds"))


# =============================================================================
# Chunk 2: Generate fishing-year activity (replaces first forvalues loop)
# =============================================================================

# A fishing year j is active for a permit record if:
#   start_date < May 1 of year j+1   (permit started before the FY ends)
#   myde       >= May 1 of year j    (permit had not ended before the FY begins)
#
# Stata forvalues loop creates one indicator column per year (a1996...a2025),
# then collapse sums across duplicate rows and clips to 1.
# R equivalent: crossing() expands rows × years, filter keeps active combos,
# distinct() deduplicates — replacing loop + collapse + clip in one pipeline.
#
# NA myde: Stata treats missing (.) as +Inf, so the myde >= fy_start condition
# is TRUE when myde is missing.  is.na(myde) preserves that behaviour in R.
#
# NOTE: crossing() temporarily expands the data ~30-fold before filtering.
# If fishery_raw is very large and runtime is a concern, a non-equi join
# (e.g., data.table or dplyr::filter on pre-computed date columns) is faster.

fishery_active <- fishery_raw %>%
  crossing(fishing_year = fishing_years) %>%
  filter(
    start_date < as.Date(paste0(fishing_year + 1, "-05-01")),
    is.na(myde) | myde >= as.Date(paste0(fishing_year,     "-05-01"))
  ) %>%
  distinct(vp_num, plan, cat, fishing_year)


# =============================================================================
# Chunk 3: Build permit_working — wide plancat dummy panel
# =============================================================================

# Stata:
#   gen plancat = plan + "_" + cat
#   drop plan cat
#   reshape wide a, i(vp_num fishing_year) j(plancat) string
#   foreach var of varlist a* { replace `var' = 0 if `var' == . }
#   renvars a*, predrop(1)       // drop the leading "a"
#   rename vp_num permit
#   save permit_working
#
# R equivalent: pivot_wider() creates one column per plancat combination;
# values_fill = 0L replaces the implicit NAs (Stata's missing) with zero,
# matching the Stata foreach loop.  The leading "a" prefix from Stata's
# reshape is not reproduced — column names are just plancat strings directly.
# NOTE: Column order will differ from Stata (pivot_wider sorts by first
# appearance); downstream code should not rely on column order.

permit_working <- fishery_active %>%
  mutate(
    plancat = paste(plan, cat, sep = "_"),
    active  = 1L
  ) %>%
  select(vp_num, fishing_year, plancat, active) %>%
  pivot_wider(
    names_from  = plancat,
    values_from = active,
    values_fill = 0L   # Stata: replace var = 0 if var == .
  ) %>%
  rename(permit = vp_num)

saveRDS(permit_working,
        file.path(output_dir, glue("permit_working_{vintage_string}.Rds")))
message(glue("Saved: permit_working_{vintage_string}.Rds"))


# =============================================================================
# Chunk 4: Pull vessel physical characteristics
# =============================================================================

vessel_query <- glue(
  "select vp.vp_num, vp.ap_num, vp.ap_year, vp.hull_id,
          vp.doc_num, vp.length, vp.grt, vp.net_tons, vp.engine_power,
          vp.crew_size, vp.date_app, vp.date_coded, vp.hullid_entry_date,
          vp.hullid_update_date, vp.ves_type, vp.ves_name
   from nefsc_garfo.permit_vps_vessel vp
   where ap_year between 1996 and {last_yr}
   order by vp_num, ap_num"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)
vessel_raw <- dbGetQuery(nova_conn, vessel_query)
dbDisconnect(nova_conn)

vessel_raw <- vessel_raw %>%
  rename_with(tolower) %>%
  # Oracle DATE columns arrive as POSIXct; convert to Date.
  # Stata: gen myhull_entry = dofc(hullid_entry_date)
  mutate(
    myhull_entry  = as.Date(hullid_entry_date),
    myhull_update = as.Date(hullid_update_date)
  ) %>%
  select(-hullid_entry_date, -hullid_update_date)


# =============================================================================
# Chunk 5: Deduplicate vessel records — one row per vp_num × ap_year
# =============================================================================

# Stata: bysort vp_num ap_year (ap_num): keep if _n == _N
# Keeps the record with the highest ap_num within each vp_num × ap_year group
# (most recent permit application for that vessel × year).
# slice_max(ap_num, n = 1, with_ties = FALSE) is the R equivalent.

vessel_panel <- vessel_raw %>%
  group_by(vp_num, ap_year) %>%
  slice_max(ap_num, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  rename(permit = vp_num)


# =============================================================================
# Chunk 6: Merge vessel data, save permit_portfolio and lobster_traps
# =============================================================================

# Stata: merge m:1 permit ap_year using vessel_panel, keep(1 3) nogen
# permit_working has one row per permit × fishing_year (wide plancat dummies).
# vessel_panel has one row per permit × ap_year (deduplicated above).
# ap_year confirmed as the correct match for fishing_year in this join.

permit_portfolio <- permit_working %>%
  left_join(
    vessel_panel %>% rename(fishing_year = ap_year),
    by = join_by(permit, fishing_year)
  )

saveRDS(permit_portfolio,
        file.path(output_dir, glue("permit_portfolio_{vintage_string}.Rds")))
message(glue("Saved: permit_portfolio_{vintage_string}.Rds"))


# Lobster trap limit by hull and year.
# Stata: keep hull_id ap_year <trap_limit_var>; duplicates drop; rename ap_year fishing_year
# NOTE: trap limit column identified as max_trap in permit_vps_vessel — verify
# the exact column name against the Oracle schema before running in production.

lobster_traps <- permit_portfolio %>%
  select(hull_id, fishing_year, max_trap) %>%
  distinct()

saveRDS(lobster_traps,
        file.path(output_dir, glue("lobster_traps_{vintage_string}.Rds")))
message(glue("Saved: lobster_traps_{vintage_string}.Rds"))
