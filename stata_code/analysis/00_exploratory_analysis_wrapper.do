cap mkdir "${data_main}\commercial"
cap mkdir "${data_main}\recreational"

cap mkdir "${data_raw}\commercial"
cap mkdir "${data_raw}\recreational"

do "$analysis_code/bsb_cams_match_coverage.do"
do "$analysis_code/prices_by_category.do"


do "$analysis_code/bsb_vessel_explorations.do"

do "$analysis_code/bsb_exploratory.do"
do "$analysis_code/bsb_exploratory_dealers.do"
do "$analysis_code/bsb_seasonal.do"

