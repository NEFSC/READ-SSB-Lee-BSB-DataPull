********************************************************************************
* Black Sea bass CAMS data dump Wrapper 
* Purpose: 	wrapper to get all the cams data
********************************************************************************
/*
This wrapper do-file pulls data from CAMS. It takes a while to run.
*/


/* Directory setup */
cap mkdir "${data_main}\commercial"
cap mkdir "${data_main}\recreational"

cap mkdir "${data_raw}\commercial"
cap mkdir "${data_raw}\recreational"

/* pull cams data */
do "$extraction_code/commercial/cams_data_dump.do"
/* pull cams keyfiles */
do "$extraction_code/commercial/cams_keyfiles.do"

