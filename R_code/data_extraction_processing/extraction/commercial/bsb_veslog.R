# =============================================================================
# Script:  bsb_veslog.R
# Purpose: Pull annual BSB commercial landings from VTR (Vessel Trip Reports)
#          to assess CAMS dealer-report coverage relative to vessel self-reports.
# Inputs:  Oracle: nefsc_garfo.trip_reports_catch,
#                  nefsc_garfo.trip_reports_images,
#                  nefsc_garfo.trip_reports_document
# Outputs: data_folder/main/commercial/veslog_annual_state_landings_{vintage_string}.Rds
#            Annual VTR landings by state.
#          data_folder/main/commercial/veslog_annual_landings_{vintage_string}.Rds
#            Annual VTR landings coastwide (collapsed across states).
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/bsb_veslog.do
#          species_id = 'BSB' is the VTR species code for Black Sea Bass.
#          tripcatg in ('1','4') restricts to commercial fishing trips.
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

here::i_am("R_code/data_extraction_processing/extraction/commercial/bsb_veslog.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# SQL joins three VTR tables:
#   trip_reports_catch    — species-level catch (kept lbs) per image record
#   trip_reports_images   — links catch records to trip documents
#   trip_reports_document — trip-level document with landing date and state
veslog_query <- glue(
  "select EXTRACT(YEAR FROM d.date_land) as year,
          d.state1,
          sum(nvl(c.kept, 0)) as kept
   from nefsc_garfo.trip_reports_catch c
   left join nefsc_garfo.trip_reports_images i
       on c.imgid = i.imgid
   left join nefsc_garfo.trip_reports_document d
       on i.docid = d.docid
   where c.species_id = 'BSB'
     and d.tripcatg in ('1', '4')
   group by EXTRACT(YEAR FROM d.date_land), state1
   order by year, state1"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

veslog_raw <- dbGetQuery(nova_conn, veslog_query)

dbDisconnect(nova_conn)


veslog_raw <- veslog_raw %>%
  rename_with(tolower) %>%
  rename(
    veslog_kept_lbs = kept,    # Stata: rename kept veslog_kept_lbs
    state           = state1   # Stata: rename state1 state
  )

# Save state-year file
state_path <- here("data_folder", "main", "commercial",
                   glue("veslog_annual_state_landings_{vintage_string}.Rds"))
if (!dir.exists(dirname(state_path))) dir.create(dirname(state_path), recursive = TRUE)
saveRDS(veslog_raw, file = state_path)
message(glue("Saved: {state_path}"))

# Collapse to coastwide annual totals
# Stata: collapse (sum) veslog_kept_lbs, by(year)
veslog_coastwide <- veslog_raw %>%
  group_by(year) %>%
  summarise(veslog_kept_lbs = sum(veslog_kept_lbs, na.rm = TRUE), .groups = "drop")

coastwide_path <- here("data_folder", "main", "commercial",
                       glue("veslog_annual_landings_{vintage_string}.Rds"))
saveRDS(veslog_coastwide, file = coastwide_path)
message(glue("Saved: {coastwide_path}"))
