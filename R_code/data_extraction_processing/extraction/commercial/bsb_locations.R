# =============================================================================
# Script:  bsb_locations.R
# Purpose: Compute landed-weight-weighted average fishing latitude and longitude
#          for commercial BSB trips, aggregated to permit-year-state level.
# Inputs:  Oracle: cams_garfo.cams_land, cams_garfo.cams_subtrip
# Outputs: data_folder/main/commercial/bsb_locations_landings_{vintage_string}.Rds
#          Weighted mean lat/lon by permit, year, and state (year >= 2000,
#          trips with known coordinates and positive landings, commercial only).
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/bsb_locations.do
#          Weighted averages are computed in SQL to avoid pulling row-level data.
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

here::i_am("R_code/data_extraction_processing/extraction/commercial/bsb_locations.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# Weighted mean lat/lon uses landed pounds (lndlb) as weights, computed in SQL.
# Filters: 167687 = BSB ITIS TSN; year >= 2000; non-null coordinates;
#          lndlb > 0; rec = 0 (commercial).
locations_query <- glue(
  "select cl.permit, cl.year, cl.itis_tsn, cl.state,
          sum(cl.lndlb)                              as landings,
          sum(cl.value)                              as value,
          sum(st.lat_dd * cl.lndlb) / sum(cl.lndlb) as lat_mean,
          sum(st.lon_dd * cl.lndlb) / sum(cl.lndlb) as lon_mean
   from cams_garfo.cams_land cl
   left join cams_garfo.CAMS_SUBTRIP st
       on cl.camsid  = st.camsid
      and cl.subtrip = st.subtrip
   where cl.itis_tsn  = 167687
     and cl.year     >= 2000
     and st.lat_dd    is not null
     and st.lon_dd    is not null
     and cl.lndlb     > 0
     and cl.rec       = 0
   group by cl.year, cl.permit, cl.itis_tsn, cl.state"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

bsb_locations <- dbGetQuery(nova_conn, locations_query)

dbDisconnect(nova_conn)


bsb_locations <- bsb_locations %>%
  rename_with(tolower) %>%
  mutate(
    year     = as.integer(year),
    itis_tsn = as.character(itis_tsn),
    landings = as.numeric(landings),
    value    = as.numeric(value),
    lat_mean = as.numeric(lat_mean),
    lon_mean = as.numeric(lon_mean),
    # Stata: encode state, gen(mys) — creates integer codes alongside state string.
    # In R a factor carries both label and integer code; as.integer(state) gives the code.
    state    = as.factor(state)
  )

output_path <- here("data_folder", "main", "commercial",
                    glue("bsb_locations_landings_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(bsb_locations, file = output_path)
message(glue("Saved: {output_path}"))
