# =============================================================================
# Script:  dealers.R
# Purpose: Pull dealer information from the permit-dealer table.
#          Produces two outputs: one row per dealer per year (most recent
#          document in each year), and one row per dealer (most recent year).
# Inputs:  Oracle: nefsc_garfo.permit_dealer
# Outputs: data_folder/main/commercial/dealers_annual_{vintage_string}.Rds
#            One row per dealer (dnum) per year.
#          data_folder/main/commercial/dealers_{vintage_string}.Rds
#            One row per dealer using the most recent year on record.
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/dealers.do
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

here::i_am("R_code/data_extraction_processing/extraction/commercial/dealers.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


dealers_query <- glue(
  "select year, dnum, dlr, strt1, strt2, city, st, zip, doc
   from nefsc_garfo.permit_dealer"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

dealers_raw <- dbGetQuery(nova_conn, dealers_query)

dbDisconnect(nova_conn)


dealers_raw <- dealers_raw %>%
  rename_with(tolower)

# Keep the row with the highest doc (document number) per dealer-year.
# Stata: bysort dnum year (doc): gen keep = _n == _N; keep if keep == 1
# with_ties = FALSE: if doc ties, keep exactly one row (deterministic).
dealers_annual <- dealers_raw %>%
  group_by(dnum, year) %>%
  slice_max(doc, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(-doc)

# Assert one row per dnum-year after deduplication.
# Stata: bysort dnum year: assert _N == 1
max_per_group <- dealers_annual %>%
  count(dnum, year) %>%
  pull(n) %>%
  max()
stopifnot("More than one row per dnum-year after slice_max" = max_per_group == 1)

# Rename address and dealer name fields.
# Stata: foreach var of varlist strt1 strt2 city st zip { rename `var' dlr_`var' }
#        rename dlr dlr_name
dealers_annual <- dealers_annual %>%
  rename(
    dlr_strt1 = strt1,
    dlr_strt2 = strt2,
    dlr_city  = city,
    dlr_st    = st,
    dlr_zip   = zip,
    dlr_name  = dlr
  )

annual_path <- here("data_folder", "main", "commercial",
                    glue("dealers_annual_{vintage_string}.Rds"))
if (!dir.exists(dirname(annual_path))) dir.create(dirname(annual_path), recursive = TRUE)
saveRDS(dealers_annual, file = annual_path)
message(glue("Saved: {annual_path}"))


# Keep only the most recent year per dealer.
# Stata: bysort dnum (year): keep if _n == _N; drop year
dealers_latest <- dealers_annual %>%
  group_by(dnum) %>%
  slice_max(year, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(-year)

latest_path <- here("data_folder", "main", "commercial",
                    glue("dealers_{vintage_string}.Rds"))
saveRDS(dealers_latest, file = latest_path)
message(glue("Saved: {latest_path}"))
