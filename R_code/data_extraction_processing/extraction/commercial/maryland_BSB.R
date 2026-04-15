# =============================================================================
# Script:  maryland_BSB.R
# Purpose: Pull Maryland commercial BSB landings aggregated to permit-year
#          level, excluding trips that landed fewer than 50 lbs.
# Inputs:  Oracle: cams_garfo.cams_land
# Outputs: data_folder/main/commercial/MD_yearly_landings_by_type_{vintage_string}.Rds
#          Permit-hullid-year landings for Maryland BSB (year >= 2010,
#          commercial only, trips > 50 lbs).
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/maryland_BSB.do
#          Maryland has a 50 lb open-access possession limit for BSB and up
#          to 14 landings permits.  Trips under the threshold are excluded.
# =============================================================================

library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)

here::i_am("R_code/data_extraction_processing/extraction/commercial/maryland_BSB.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# SQL: sum to permit-hullid-camsid-year, drop trips <= 50 lbs,
# then aggregate to permit-hullid-year.
# 167687 = ITIS TSN for Black Sea Bass; state = 'MD'; rec = 0 = commercial.
md_query <- glue(
  "select permit, hullid, year,
          sum(landings) as landings,
          sum(value)    as value
   from (
     select permit, hullid, camsid, year,
            sum(nvl(lndlb, 0)) as landings,
            sum(nvl(value, 0)) as value
     from cams_garfo.cams_land cl
     where cl.itis_tsn = 167687
       and cl.state    = 'MD'
       and cl.year    >= 2010
       and cl.rec      = 0
     group by permit, hullid, camsid, year
   ) A
   where A.landings > 50
   group by permit, hullid, year
   order by year, landings"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

md_landings <- dbGetQuery(nova_conn, md_query)

dbDisconnect(nova_conn)


md_landings <- md_landings %>%
  rename_with(tolower) %>%
  mutate(permit = as.character(permit))  # keep as character to preserve leading zeros

output_path <- here("data_folder", "main", "commercial",
                    glue("MD_yearly_landings_by_type_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(md_landings, file = output_path)
message(glue("Saved: {output_path}"))
