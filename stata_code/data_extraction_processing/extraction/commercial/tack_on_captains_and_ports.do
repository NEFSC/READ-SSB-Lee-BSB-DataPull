********************************************************************************
* tack_on_captains_and_ports.do
* Purpose: Links captain/operator identity data from an external project
*          to BSB trip records; produces two operator key datasets:
*            data_main/commercial/tripid_operator.dta
*            data_main/commercial/jops_operator.dta
*
* NOT PART OF THE STANDARD BSB PIPELINE. This file bridges data from an
* external "mobility" and "space panels" project into the BSB data.
* Safe to ignore if running only the core BSB extraction.
*
* Requires globals defined by the EXTERNAL project before this file runs:
*   $mobility       — path to the mobility project's setup script
*   $data_nameclean — path to the cleaned operator data files
*
* Note: the lines that do $mobility and do $BSBDataPull is a lazy way to set up paths (it gets data_main). 
********************************************************************************
do $mobility

global spacepanels_vintage 2023_04_06


use "$data_nameclean/vsh_operator_key_mod.dta", replace
keep permit tripid dbyear portlnd1 state1 geoid operator operator_key_modified
duplicates drop
compress

do $BSBDataPull

save "$data_main/commercial/tripid_operator.dta", replace


do $mobility

use "$data_nameclean/jops_operator_clean.dta", replace
keep  operator_key_modified operator_key jops_full de address1 city address_key address2 st zip address_date


do $BSBDataPull

save "$data_main/commercial/jops_operator.dta", replace
