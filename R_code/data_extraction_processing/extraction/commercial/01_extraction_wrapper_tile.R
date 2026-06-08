###############################################################
# Tilefish extraction wrapper
# Purpose: 	wrapper to get data for the prices in stock assessment project
# Requires: ODBC connection to NEFSC/GARFO Oracle databases.
# Outputs:  17 datasets in data_folder/main/commercial/
#  See README.md ## Execution Guide for full prerequisites and run order.
###############################################################

#
#  itis_tsn == "168543" ~ "TILEFISH, BLUELINE",
#  itis_tsn == "168546" ~ "TILEFISH, (GOLDEN TILEFISH)",
#  itis_tsn == "168537" ~ "TILEFISH, UNC",
#  itis_tsn == "168544" ~ "TILEFISH, GOLDFACE",

#  this is a port of  
#  These are a bit meandering.  There's lots of little one-off investigations.


library("ROracle")
library("glue")
library("tidyverse")
library("lubridate")

library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(lubridate::year)
conflicts_prefer(lubridate::month)
conflicts_prefer(lubridate::week)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::arrange)

here::i_am("R_code/data_extraction_processing/extraction/commercial/01_extraction_wrapper.R")


vintage_string <- format(Sys.Date())

# last_yr for permit extractions
permit_extract_last_yr      <- 2025
permit_extract_fishing_fishing_years <- 1996:permit_extract_last_yr

tilefish_itis_codes<- c("168543","168546","168537","168544")
tilefish_itis_codes<- c("168546")


codes_sql <- glue_collapse(glue("'{tilefish_itis_codes}'"), sep = ", ")

# ============================================================
# EXECUTION CONTROL
# ============================================================

run_cams_gears    <- TRUE   # Module 3 : pulls cfg_gear
run_tile_daily <- TRUE   # Module 6:   Pull daily commercial tilefish at the trip-state-species level
run_tile_price_categories<- TRUE  # Module 7:   keyfile and daily landings
run_extractFRED      <- TRUE  # Module 10:    dfelators
run_tile_transactions      <- TRUE   # Module 11: main dataset. most important data pull for the Prices in stock assessment Project



# Display execution plan
modules <- tibble::tribble(
  ~label,                              ~flag,
  "Module 3:       cfg_gear",      run_cams_gears,
  "Module 6:   Pull daily commercial sfsbsb at the trip-state-species level",run_tile_daily,
  "Module 7:   keyfile and daily landings",run_tile_price_categories,
  "Module 10:    dfelators",run_extractFRED,
  "Module 11: main dataset. most important data pull for the Prices in stock assessment Project",run_tile_transactions,
  )

      





message("Execution Plan:")
for (i in seq_len(nrow(modules))) {
  message(modules$label[i], ": ", ifelse(modules$flag[i], "RUN", "SKIP"))
}

# ============================================================
# MODULE EXECUTION
# ============================================================

if(run_cams_gears)   {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "cams_gears.R"))
}
if(run_tile_daily) { 
  source(here("R_code", "data_extraction_processing","extraction","commercial", "tile_daily.R"))
}
if(run_tile_price_categories)  {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "tile_price_categories.R"))
}
if(run_extractFRED)      {
  source(here("R_code", "data_extraction_processing","extraction", "extract_data_from_FRED.R"))
}
if(run_tile_transactions) {     
  source(here("R_code", "data_extraction_processing","extraction","commercial", "tile_transactions.R")) # this is the most important data pull for the Prices in stock assessment Project
}
