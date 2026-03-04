********************************************************************************
* Black Sea bass extraction wrapper 
* Purpose: 	wrapper to get data for the prices in stock assessment project
********************************************************************************
/*
These are a bit meandering.  There's lots of little one-off investigations.

*/


/* code to pull Maryland "IFQ" landings by permit */
do "$extraction_code/commercial/maryland_BSB.do"
do "$extraction_code/commercial/commercial_BSB.do"
do "$extraction_code/commercial/cams_gears.do"
do "$extraction_code/commercial/bsb_weekly.do"
do "$extraction_code/commercial/dealers.do"
do "$extraction_code/commercial/sfbsb_daily.do"


do "$extraction_code/commercial/bsb_price_categories.do"


do "$extraction_code/commercial/bsb_locations.do"
do "$extraction_code/commercial/bsb_transactions.do"  /* this is the most important data pull for the Prices in stock assessment Project */
do "$extraction_code/commercial/bsb_veslog.do"
do "$extraction_code/extract_data_from_FRED.do"

do "$extraction_code/permit_characteristics_extractions.do"

do "$extraction_code/commercial/valid_fishery_extraction.do"

do "$extraction_code/commercial/bsb_dersource_investigations.do"

do "$extraction_code/commercial/observer_fuel_prices.do"



do "$extraction_code/commercial/portlnd1_supplement.do"
