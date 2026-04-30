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
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)

here::i_am("R_code/data_extraction_processing/extraction/commercial/01_extraction_wrapper.R")


vintage_string <- format(Sys.Date())

# ============================================================
# EXECUTION CONTROL
# ============================================================

run_maryland_BSB      <- TRUE   # Module 1:   Maryland BSB by permit
run_commercial_BSB <- TRUE   # Module 2 : Pull annual BSB commercial landings by permit, classifying
run_cams_gears    <- TRUE   # Module 3 
run_bsb_weekly        <- TRUE   # Module 3:   Geographic data processing
run_dealers    <- TRUE   # Module 4:   Summary statistics/descriptive outputs
run_sfsbsb_daily <- TRUE   # Module 5:   Hedonic price regression and prediction
run_bsb_price_categories<- TRUE  # Module 6:   Discrete choice model estimation
run_bsb_transactions      <- TRUE  # Unnamed:    QAQC of mata functions
run_bsb_veslog      <- TRUE  # Unnamed:    QAQC of mata functions
run_extractFRED      <- TRUE  # Unnamed:    QAQC of mata functions
run_bsb_transactions      <- TRUE   # this is the most important data pull for the Prices in stock assessment Project
run_bsb_veslog      <- TRUE  # Unnamed:    QAQC of mata functions
run_permit_char      <- TRUE  # Unnamed:    QAQC of mata functions
run_valid_fishery      <- TRUE  # Unnamed:    QAQC of mata functions
run_dersource      <- TRUE  # Unnamed:    QAQC of mata functions
run_fuel_prices      <- TRUE  # Unnamed:    QAQC of mata functions
run_portlnd1      <- TRUE  # Unnamed:    QAQC of mata functions




# Display execution plan
modules <- tibble::tribble(
  ~label,                              ~flag,
  "Module 1:   Maryland BSB by permit",  run_maryland_BSB,
  "Module 1.5:     Commercial Permits",    run_commercial_BSB,
  "Module 2:       Cleaning/Merging",  run_bsb_weekly,
  "Module 3:       Mapping Prep",      run_dealers,
  "Module 4:       Descriptive",       run_sfsbsb_daily,
  "Module 5:       Price Modeling",    run_bsb_price_categories,
  "Module 6:       Choice Modeling",   run_bsb_transactions,
  "Module unnamed: QAQC mata",         run_bsb_veslog
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
if(run_dealers)  {     
  source(here("R_code", "data_extraction_processing","extraction","commercial", "dealers.R"))
}
if(run_sfsbsb_daily) { 
  source(here("R_code", "data_extraction_processing","extraction","commercial", "sfbsb_daily.R"))
}
if(run_bsb_price_categories)  {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_price_categories.R"))
}
if(run_bsb_locations) {       
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_locations.R"))
}
if(run_bsb_transactions)   {    
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_transactions.R"))
}
if(run_bsb_veslog)     { 
  source(here("R_code", "data_extraction_processing","extraction","commercial","bsb_veslog.R"))
}
if(run_extractFRED)      {
  source(here("R_code", "data_extraction_processing","extraction","commercial", "extract_data_from_FRED.R"))
}
if(run_bsb_locations) {      
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_locations.R"))
}
if(run_bsb_transactions) {     
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_transactions.R")) # this is the most important data pull for the Prices in stock assessment Project
}
if(run_bsb_veslog)   { 
  source(here("R_code", "data_extraction_processing","extraction","commercial", "bsb_veslog.R"))
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

