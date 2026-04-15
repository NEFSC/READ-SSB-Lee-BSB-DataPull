# =============================================================================
# Script:  sfbsb_daily.R
# Purpose: Pull daily commercial landings for Black Sea Bass and Summer Flounder,
#          aggregated by trip date, state, and species.
# Inputs:  Oracle: cams_garfo.cams_land
# Outputs: data_folder/main/commercial/daily_{vintage_string}.Rds
#          Daily landings and price by species and state (commercial only).
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/sfbsb_daily.do
#          ITIS TSN: 167687 = Black Sea Bass, 172735 = Summer Flounder
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
conflicts_prefer(dplyr::summarise)

here::i_am("R_code/data_extraction_processing/extraction/commercial/sfbsb_daily.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


daily_query <- glue(
  "select TO_CHAR(trunc(date_trip), 'MM-DD-YYYY') as date_trip_str,
          itis_tsn,
          sum(nvl(value,   0)) as value,
          sum(nvl(lndlb,   0)) as landings,
          state
   from cams_garfo.cams_land
   where itis_tsn in ('167687', '172735')
     and rec = 0
   group by TO_CHAR(trunc(date_trip), 'MM-DD-YYYY'), state, itis_tsn"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

daily <- dbGetQuery(nova_conn, daily_query)

dbDisconnect(nova_conn)


daily <- daily %>%
  rename_with(tolower) %>%
  mutate(
    date_trip    = as.Date(date_trip_str, format = "%m-%d-%Y"),
    year         = year(date_trip),
    landings     = as.numeric(landings),
    value        = as.numeric(value),
    itis_tsn     = as.character(itis_tsn),
    # Stata: encode state, gen(mys) — factor carries label and integer code
    state        = as.factor(state),
    # Human-readable species name (replaces Stata label define / label value)
    species_name = case_when(
      itis_tsn == "167687" ~ "Black Sea Bass",
      itis_tsn == "172735" ~ "Summer Flounder",
      TRUE                 ~ NA_character_
    ),
    # price = value / lndlb (landed-weight pounds)
    price = if_else(landings > 0, value / landings, NA_real_)
  ) %>%
  select(-date_trip_str) %>%
  # Stata: order year date_trip value landings state mys price
  relocate(year, date_trip, value, landings, state, species_name, price)

output_path <- here("data_folder", "main", "commercial",
                    glue("daily_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(daily, file = output_path)
message(glue("Saved: {output_path}"))
