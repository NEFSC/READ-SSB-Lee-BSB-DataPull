###############################################################
# Black Sea bass extraction wrapper
# Purpose: 	wrapper to get data for the prices in stock assessment project
# Requires: ODBC connection to NEFSC/GARFO Oracle databases.
# Outputs:  17 datasets in data_folder/main/commercial/
#  See README.md ## Execution Guide for full prerequisites and run order.
###############################################################

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

# ============================================================
# EXECUTION CONTROL
# ============================================================

run_maryland_BSB      <- TRUE   # Module 1:   Maryland BSB by permit
run_commercial_BSB <- TRUE   # Module 2 : Pull annual BSB commercial landings by permit, classifying
run_cams_gears    <- TRUE   # Module 3 : pulls cfg_gear
run_bsb_weekly        <- TRUE   # Module 4:   Pull daily BSB commercial landings and aggregate to weekly 
run_dealers    <- TRUE   # Module 5:   pull dealer attributes
run_sfsbsb_daily <- TRUE   # Module 6:   Pull daily commercial sfsbsb at the trip-state-species level
run_bsb_price_categories<- TRUE  # Module 7:   keyfile and daily landings
run_bsb_veslog      <- TRUE  # Module 9:    Pull annual BSB commercial landings
run_extractFRED      <- TRUE  # Module 10:    dfelators
run_bsb_transactions      <- TRUE   # Module 11: main dataset. most important data pull for the Prices in stock assessment Project
run_bsb_locations      <- TRUE  # Module 12:    compute landed weight average fishing lat and long for commercial
run_permit_char      <- TRUE  # Module 13:    Build a permit-fishing_year panel of plan-cat, characteristics, and lobster traps
run_valid_fishery      <- TRUE  # Module 14:    active plan/category combinations
run_dersource      <- TRUE  # Module 15:    QA investigation of BSB commercial landings
run_fuel_prices      <- TRUE  # Module 16:    Pull fuel prices for observer
run_portlnd1      <- TRUE  # Module 17:    tack on landed ports



# Display execution plan
modules <- tibble::tribble(
  ~label,                              ~flag,
  "Module 1:   Maryland BSB by permit",  run_maryland_BSB,
  "Module 2:     Commercial Permits",    run_commercial_BSB,
  "Module 3:       cfg_gear",      run_cams_gears,
  "Module 4:       daily BSB commercial landings",       run_bsb_weekly,
  "Module 5:   pull dealer attributes",run_dealers,
  "Module 6:   Pull daily commercial sfsbsb at the trip-state-species level",run_sfsbsb_daily,
  "Module 7:   keyfile and daily landings",run_bsb_price_categories,
  "Module 9:    Pull annual BSB commercial landings",run_bsb_veslog,
  "Module 10:    dfelators",run_extractFRED,
  "Module 11: main dataset. most important data pull for the Prices in stock assessment Project",run_bsb_transactions,
  "Module 12:    compute landed weight average fishing lat and long for commercial",run_bsb_locations,
  "Module 13:    Build a permit-fishing_year panel of plan-cat, characteristics, and lobster traps",run_permit_char,
  "Module 14:    active plan/category combinations",run_valid_fishery,
  "Module 15:    QA investigation of BSB commercial landings",  run_dersource,
  "Module 16:    Pull fuel prices for observer", run_fuel_prices,
  "Module 17:    tack on landed ports", run_portlnd1
  )

      





message("Execution Plan:")
for (i in seq_len(nrow(modules))) {
  message(modules$label[i], ": ", ifelse(modules$flag[i], "RUN", "SKIP"))
}

# ============================================================
# MODULE EXECUTION
# ============================================================

if (run_maryland_BSB) {
  source(here("R_code", "data_extraction_processing","extraction","commercial","maryland_BSB.R"))
}

if (run_commercial_BSB)  {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "commercial_BSB.R"))
}
if(run_cams_gears)   {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "cams_gears.R"))
}
if(run_bsb_weekly)   {    
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_weekly.R"))
}

# bsb weekly landings produces state instead of mys
# The landings, value, and price are slightly different. my guess is because of the way the weekly aggregation is done 
# produces year and week columns instead of weekly_date

if(run_dealers)  {     
  source(here("R_code", "data_extraction_processing","extraction","commercial", "dealers.R"))
}
if(run_sfsbsb_daily) { 
  source(here("R_code", "data_extraction_processing","extraction","commercial", "sfbsb_daily.R"))
}
if(run_bsb_price_categories)  {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_price_categories.R"))
}
if(run_bsb_veslog)     { 
  source(here("R_code", "data_extraction_processing","extraction","commercial","bsb_veslog.R"))
}
if(run_extractFRED)      {
  source(here("R_code", "data_extraction_processing","extraction", "extract_data_from_FRED.R"))
}
if(run_bsb_locations) {      
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_locations.R"))
}
if(run_bsb_transactions) {     
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_transactions.R")) # this is the most important data pull for the Prices in stock assessment Project
}
if(run_permit_char) {      
  source(here("R_code", "data_extraction_processing","extraction","commercial", "permit_characteristics_extractions.R"))
}
if(run_valid_fishery)   {   
  source(here("R_code", "data_extraction_processing","extraction","commercial","valid_fishery_extraction.R"))
}
if(run_dersource)  {    
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_dersource_investigations.R"))
}
if(run_fuel_prices) {    
  source(here("R_code", "data_extraction_processing","extraction","commercial", "observer_fuel_prices.R"))
}
if(run_portlnd1) {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "portlnd1_supplement.R"))
}

