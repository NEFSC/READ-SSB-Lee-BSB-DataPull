# =============================================================================
# Script:  investigate_cams_stockeff.R
# Purpose: Investigate differences between cams and stockeff
# Inputs:  
# File:   input_path  <- here("data_folder", "main", "commercial")
# input_path <- glue("landings_all_{vintage_string}.Rds")
# input_path <- file.path(output_dir, input_path)
# landings_all<-readRDS(file = input_path)
# created by bsb_transactions.R
# =============================================================================

library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::arrange)

here::i_am("R_code/analysis/investigate_cams_stockeff.R")

vintage_string <-"2026-04-15"

# sql_query <- glue(
#   "select st.docid, st.subtrip, st.area, st.negear, st.mesh_cat,
#           st.record_sail, st.record_land, st.ves_len,
#           cl.dlr_stid, cl.dlr_cflic, cl.camsid, cl.permit, cl.hullid,
#           cl.year, cl.month, cl.week, cl.dlr_date,
#           cl.dlr_mkt   as market_code,
#           cl.dlr_grade as grade_code,
#           cl.dlrid, cl.itis_tsn, cl.state, cl.port,
#           cl.lndlb, cl.value, cl.livlb,
#           cl.status, cl.dlr_source, cl.rec,
#           st.lat_dd, st.lon_dd
#    from cams_garfo.cams_land cl
#    LEFT JOIN cams_garfo.cams_subtrip st
#        on cl.camsid  = st.camsid
#       and cl.subtrip = st.subtrip
#    where cl.itis_tsn = '167687'
#      and cl.rec = 0"
# )

# Establish Oracle connection.  
# should be available in the session via keyring or .Rprofile.
# See documentation/project_logistics.md for credential setup instructions.
drv       <- dbDriver("Oracle")
#nova_conn <- eval(nefscdb_con)


#dbDisconnect(nova_conn)


# =============================================================================
# Section 1: READ in results of bsb_transactions
# =============================================================================

input_path  <- here("data_folder", "main", "commercial")
input_file <- glue("landings_all_{vintage_string}.Rds")
input_path <- file.path(input_path, input_file)


landings_all<-readRDS(file = input_path)

landings_all <- landings_all %>%
  mutate(
    stockarea = case_when(
      area >= 621 & area<=640 ~ "SOUTH",
      area %in% c(614, 615)   ~ "SOUTH",
      area == 616              ~ "NORTH",
      area <= 613           ~ "NORTH",
      area==0 ~ "UNK",
      .default = "UNK"
    )
  )

  

aggregated_landings<-landings_all %>%

  group_by(year,stockarea) %>%
  summarise(livkg=sum(livlb/2.204))


output_dir  <- here("data_folder", "main", "commercial")
output_file <- glue("aggregated_landings_cams_check{vintage_string}.Rds")
output_path <- file.path(output_dir, output_file)

saveRDS(aggregated_landings, file = output_path)
