cap mkdir "${data_main}\commercial"
cap mkdir "${data_main}\recreational"

cap mkdir "${data_raw}\commercial"
cap mkdir "${data_raw}\recreational"

do "$extraction_code/commercial/cams_data_dump.do"
do "$extraction_code/commercial/cams_keyfiles.do"

