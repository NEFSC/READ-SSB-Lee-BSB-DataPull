********************************************************************************
* Black Sea bass CAMS data dump  
* Purpose: 	Get cams data
********************************************************************************
/*

CAMS is a GARFO data project that joins together all sorts of data. 

Informationa about CAMS can be found here
https://apps-garfo.fisheries.noaa.gov/cams/

Social Science specific tips can be found here
https://github.com/NEFSC/READ-SSB-metadata


The code was intially set up to use jdbc to extract data. that takes a long time and weve used odbc instead .
*/




#delimit ;

/*jdbc connect , jar("$jar")  driverclass("$classname")  url("$NEFSC_USERS_URL")  user("$myuid") password("$mypwd");
*/
global firstyr 1996;
global lastyr = 2025;
clear;


cap mkdir $data_raw/commercial/temp ;


/* year by year, pull cams_land data */
/* the files are so large, that you might have problems getting everything */

foreach y of numlist $firstyr(1)$lastyr{;

	/* landings */

	local sql "select * from cams_garfo.cams_land cl
		where cl.year=`y' and cl.rec=0" ; 


	clear;
	/*jdbc load, exec("`sql' ") case(lower);*/

	odbc load, exec("`sql'; ")  $myNEFSC_USERS_conn;

	compress;
	notes: "`sql'";


	save $data_raw/commercial/temp/cams_land_`y'_$vintage_string.dta, replace;

};

/* append the data together and save in a single file*/

local landfiles: dir "$data_raw/commercial/temp" files "cams_land_*_$vintage_string.dta" ;

clear;
foreach l of local landfiles{;
	append using $data_raw/commercial/temp/`l'	;
};
notes: Joins of CAMS_LAND to CAMS_SUBTRIP must be done on CAMSID and subtrip;
capture destring docid dlrid dlr_stid permit dlr_cflic port bhc subtrip dlr_rptid dlr_utilcd dlr_source dlr_toncl fzone vtr_catchid vtr_dlrid itis_tsn dlr_catch_source dlr_grade dlr_disp rec nemarea area negear sectid, replace;
compress;

save $data_main/commercial/cams_land_$vintage_string.dta, replace;

/* delete the yearly files*/

foreach y of numlist $firstyr(1)$lastyr{;
	rm $data_raw/commercial/temp/cams_land_`y'_$vintage_string.dta ;
};




/* repeat for the trip level information */	
	
	foreach y of numlist $firstyr(1)$lastyr{;

	/*subtrip */

	clear;
	local sql "select * from cams_garfo.cams_subtrip where year=`y'" ; 
	
	/*	
	jdbc load, exec("`sql'") case(lower);
	*/
	odbc load, exec("`sql'; ")  $myNEFSC_USERS_conn;

	notes: "`sql'";
	notes: Joins of CAMS_SUBTRIP to CAMS_LAND must be done on CAMSID and subtrip;
	save $data_raw/commercial/temp/cams_subtrip_`y'_$vintage_string.dta, replace;

	} ;
	
	
	
local st: dir "$data_raw/commercial/temp" files "cams_subtrip_*_$vintage_string.dta" ;
clear;
foreach l of local st{;
	append using $data_raw/commercial/temp/`l'	;
};
destring, replace;
compress;

notes: Joins of CAMS_SUBTRIP to CAMS_LAND must be done on CAMSID and subtrip ;
save $data_main/commercial/cams_subtrip_$vintage_string.dta, replace;
	
	
	
	foreach y of numlist $firstyr(1)$lastyr{;
	rm $data_raw/commercial/temp/cams_subtrip_`y'_$vintage_string.dta ;
};

	
	
	
	
	
	/* repeat for the VTR_ORPHAN_SUBTRIP information. VTR_ORPHANS_SUBTRIP are VTR records that did not match to a Dealer record */	

	foreach y of numlist $firstyr(1)$lastyr{;

	/* orphan subtrip */
	clear;


	local sql "select * from cams_garfo.CAMS_VTR_ORPHANS_SUBTRIP where year=`y'" ; 
		
		
	/*	
	jdbc load, exec("`sql'") case(lower);
	*/
	odbc load, exec("`sql'; ")  $myNEFSC_USERS_conn;

	destring, replace;
	compress;

	notes: "`sql'";


	save $data_raw/commercial/temp/cams_orphan_subtrip_`y'_$vintage_string.dta, replace;

};




local ost: dir "$data_raw/commercial/temp" files "cams_orphan_subtrip_*_$vintage_string.dta" ;
clear;
foreach l of local ost{;
	append using $data_raw/commercial/temp/`l'	, force;
};

save $data_main/commercial/cams_orphan_subtrip_$vintage_string.dta, replace;



	foreach y of numlist $firstyr(1)$lastyr{;
	rm $data_raw/commercial/temp/cams_orphan_subtrip_`y'_$vintage_string.dta ;
};

	
	




