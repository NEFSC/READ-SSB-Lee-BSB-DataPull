# =============================================================================
# Script:  commercial_BSB.R
# Purpose: (1) Pull annual BSB commercial landings by permit, classifying
#          vessels as state or federally permitted.
#          (2) Pull trip-level landings of all species from trips that landed
#          at least 100 lbs of BSB, then collapse to annual species totals.
# Inputs:  Oracle: cams_garfo.cams_land
# Outputs: data_folder/main/commercial/yearly_landings_by_type_{vintage_string}.Rds
#            Annual BSB landings by permit with STATE/FEDERAL classification.
#          data_folder/main/commercial/subtrip_landings_{vintage_string}.Rds
#            Trip-level landings of all species on BSB trips (>= 100 lbs BSB).
#          data_folder/main/commercial/annual_landings_on_BSB_trips_{vintage_string}.Rds
#            Annual species totals on BSB trips, with share of total value.
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/commercial_BSB.do
#          Permit codes: "000000" = state (no federal permit),
#          "190998"/"290998"/"390998"/"490998" = vessel size classes A-D.
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

here::i_am("R_code/data_extraction_processing/extraction/commercial/commercial_BSB.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# =============================================================================
# Section 1: Oracle queries
# =============================================================================

# Query 1: Annual BSB landings aggregated to permit-year level.
# 167687 = ITIS TSN for Black Sea Bass; rec = 0 = commercial.
yearly_query <- glue(
  "select permit, year,
          sum(nvl(lndlb, 0)) as landings,
          sum(nvl(value, 0)) as value,
          itis_tsn
   from cams_garfo.cams_land cl
   where cl.itis_tsn = 167687
     and cl.rec = 0
   group by permit, year, itis_tsn"
)

# Query 2: All-species landings from trips that landed >= 100 lbs of BSB.
# The inner subquery identifies qualifying CAMSIDs; the outer query sums
# all species on those trips.
# NOTE: inner subquery references cams_garfo.cams_land with full schema prefix
# (the Stata original omits the schema — may work if default schema is set).
subtrip_query <- glue(
  "select sum(lndlb)  as landings,
          sum(value)  as value,
          year, state, itis_tsn, itis_group1
   from cams_garfo.cams_land
   where camsid in (
     select distinct camsid
     from (
       select camsid, sum(lndlb) as landings
       from cams_garfo.cams_land
       where itis_tsn = 167687 and rec = 0
       group by camsid
     )
     where landings > 100
   )
   group by year, state, itis_tsn, itis_group1"
)

drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

yearly_raw  <- dbGetQuery(nova_conn, yearly_query)
subtrip_raw <- dbGetQuery(nova_conn, subtrip_query)

dbDisconnect(nova_conn)


# =============================================================================
# Section 2: Process yearly landings by permit type
# =============================================================================

yearly_landings <- yearly_raw %>%
  rename_with(tolower) %>%
  mutate(
    permit   = as.character(permit),  # keep as character to preserve leading zeros
    landings = as.numeric(landings),
    value    = as.numeric(value),
    itis_tsn = as.character(itis_tsn),
    # Classify permit type.
    # "000000" = state-permitted vessel (no federal permit)
    # x98 codes = vessel size classes A-D with unknown/no permit number
    type = if_else(
      permit %in% c("000000", "190998", "290998", "390998", "490998"),
      "STATE", "FEDERAL"
    )
  )

yearly_path <- here("data_folder", "main", "commercial",
                    glue("yearly_landings_by_type_{vintage_string}.Rds"))
if (!dir.exists(dirname(yearly_path))) dir.create(dirname(yearly_path), recursive = TRUE)
saveRDS(yearly_landings, file = yearly_path)
message(glue("Saved: {yearly_path}"))


# =============================================================================
# Section 3: Process trip-level all-species landings
# =============================================================================

subtrip_landings <- subtrip_raw %>%
  rename_with(tolower) %>%
  mutate(
    landings  = as.numeric(landings),
    value     = as.numeric(value),
    year      = as.integer(year),
    itis_tsn  = as.character(itis_tsn),
    itis_group1 = as.character(itis_group1)
  )

subtrip_path <- here("data_folder", "main", "commercial",
                     glue("subtrip_landings_{vintage_string}.Rds"))
saveRDS(subtrip_landings, file = subtrip_path)
message(glue("Saved: {subtrip_path}"))


# =============================================================================
# Section 4: Collapse to annual species totals with value share
# =============================================================================

# Stata: collapse (sum) landings value, by(itis_tsn year itis_group)
# Note: Stata code names the variable itis_group in the collapse but the SQL
# returns itis_group1; itis_group1 is used here.
annual_landings <- subtrip_landings %>%
  group_by(itis_tsn, year, itis_group1) %>%
  summarise(
    landings = sum(landings, na.rm = TRUE),
    value    = sum(value,    na.rm = TRUE),
    .groups  = "drop"
  ) %>%
  # pct = share of total landed value within each year
  # Stata: bysort year: egen tv = total(value); gen pct = value/tv
  group_by(year) %>%
  mutate(pct = value / sum(value)) %>%
  ungroup() %>%
  # Stata: gsort year -pct
  arrange(year, desc(pct))

annual_path <- here("data_folder", "main", "commercial",
                    glue("annual_landings_on_BSB_trips_{vintage_string}.Rds"))
saveRDS(annual_landings, file = annual_path)
message(glue("Saved: {annual_path}"))
