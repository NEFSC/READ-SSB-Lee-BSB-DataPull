********************************************************************************
* Exploratory analysis wrapper
* Purpose: 	runs all BSB exploratory analysis scripts; produces 70+ graphs
* Step 2 in the execution sequence — requires Step 1B outputs in data_folder/main/commercial/
* *** Before running: update global in_string below to match your extraction
*     vintage string (format: YYYY_MM_DD, set by folder_setup_globals.do). ***
* See README.md ## Execution Guide for full prerequisites and run order.
********************************************************************************
global in_string 2025_07_09
global in_string 2026_04_30


do "$analysis_code/bsb_cams_match_coverage.do"
do "$analysis_code/prices_by_category.do"


do "$analysis_code/bsb_vessel_explorations.do"

do "$analysis_code/bsb_exploratory.do"
do "$analysis_code/bsb_exploratory_dealers.do"
do "$analysis_code/bsb_seasonal.do"

