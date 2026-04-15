# =============================================================================
# Script:  bsb_weekly.R
# Purpose: Pull daily BSB commercial landings and aggregate to weekly totals
#          by state, computing a weekly average price.
# Inputs:  Oracle: cams_garfo.cams_land
# Outputs: data_folder/main/commercial/weekly_landings_{vintage_string}.Rds
#          Weekly landings, value, and price by state (commercial BSB only).
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/bsb_weekly.do
#          The Stata script creates a weekly_date serial and calls tsset for
#          time-series declaration; neither has a meaningful R equivalent and
#          both are omitted.  year and week (integer) are retained instead.
# Author:
# Date:
# =============================================================================

library("ROracle")
library("glue")
library("tidyverse")
library("lubridate")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(lubridate::year)
conflicts_prefer(lubridate::week)
conflicts_prefer(dplyr::summarise)

here::i_am("R_code/data_extraction_processing/extraction/commercial/bsb_weekly.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# SQL returns daily totals by date and state; R aggregates to weekly below.
# 167687 = ITIS TSN for Black Sea Bass; rec = 0 = commercial.
weekly_query <- glue(
  "select TO_CHAR(trunc(dlr_date), 'MM-DD-YYYY') as dlr_date_str,
          sum(value)  as value,
          sum(lndlb)  as landings,
          state
   from cams_garfo.cams_land
   where itis_tsn = '167687'
     and rec = 0
   group by TO_CHAR(trunc(dlr_date), 'MM-DD-YYYY'), state"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

daily_raw <- dbGetQuery(nova_conn, weekly_query)

dbDisconnect(nova_conn)


daily_raw <- daily_raw %>%
  rename_with(tolower) %>%
  mutate(
    dlr_date = as.Date(dlr_date_str, format = "%m-%d-%Y"),
    year     = year(dlr_date),
    # NOTE: lubridate::week() counts from Jan 1 (week 1 contains Jan 1),
    # matching Stata's week() function.
    week     = week(dlr_date),
    landings = as.numeric(landings),
    value    = as.numeric(value),
    # Stata: encode state, gen(mys) — factor carries label and integer code
    state    = as.factor(state)
  ) %>%
  select(-dlr_date_str)

# Stata: collapse (sum) landings value, by(mys weekly_date)
# Group by state + year + week (weekly_date omitted — see Notes above).
weekly_landings <- daily_raw %>%
  group_by(state, year, week) %>%
  summarise(
    landings = sum(landings, na.rm = TRUE),
    value    = sum(value,    na.rm = TRUE),
    .groups  = "drop"
  ) %>%
  mutate(price = if_else(landings > 0, value / landings, NA_real_)) %>%
  arrange(state, year, week)

output_path <- here("data_folder", "main", "commercial",
                    glue("weekly_landings_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(weekly_landings, file = output_path)
message(glue("Saved: {output_path}"))
