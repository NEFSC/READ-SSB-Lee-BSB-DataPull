# =============================================================================
# Script:  valid_fishery_extraction.R
# Purpose: Pull the valid fishery permit table — a reference listing all
#          active plan/category combinations by permit year, with dates and
#          access type (limited vs open access, mandatory VTR reporting).
# Inputs:  Oracle: nefsc_garfo.permit_valid_fishery
# Outputs: data_folder/main/commercial/vps_valid_fishery_{vintage_string}.Rds
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/valid_fishery_extraction.do
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

here::i_am("R_code/data_extraction_processing/extraction/commercial/valid_fishery_extraction.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())

# Update last_yr each year to extend the extraction range.
# Stata equivalent: global lastyr 2025
last_yr <- 2025

fishery_query <- glue(
  "select fishery_id, plan, cat,
          permit_year      as ap_year,
          descr,
          moratorium_fishery,
          mandatory_reporting,
          per_yr_start_date,
          per_yr_end_date,
          fishery_type
   from nefsc_garfo.permit_valid_fishery vf
   where permit_year between 1996 and {last_yr}
   order by plan, cat, permit_year"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

valid_fishery <- dbGetQuery(nova_conn, fishery_query)

dbDisconnect(nova_conn)


valid_fishery <- valid_fishery %>%
  rename_with(tolower) %>%
  # Oracle DATE columns arrive as POSIXct via ROracle; convert to Date.
  # Stata equivalent: replace per_yr_start_date = dofc(per_yr_start_date)
  mutate(
    per_yr_start_date = as.Date(per_yr_start_date),
    per_yr_end_date   = as.Date(per_yr_end_date)
  )

output_path <- here("data_folder", "main", "commercial",
                    glue("vps_valid_fishery_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(valid_fishery, file = output_path)
message(glue("Saved: {output_path}"))
