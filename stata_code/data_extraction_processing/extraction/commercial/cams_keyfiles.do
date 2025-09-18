********************************************************************************
* Black Sea bass cams keyfiles  
* Purpose: 	Get cams keyfiles
********************************************************************************
/*
This pulls the keyfiles from CAMS. It is pretty quick to run.

CAMS is a GARFO data project that joins together all sorts of data. 

Informationa about CAMS can be found here
https://apps-garfo.fisheries.noaa.gov/cams/

Social Science specific tips can be found here
https://github.com/NEFSC/READ-SSB-metadata


The code was intially set up to use jdbc to extract data. that takes a long time and weve used odbc instead .
*/





# delimit ;
/* ITIS TSN keyfile

This gets the ITIS TSNs which decodes the numeric keys into species names.

*/
clear;
jdbc connect , jar("$jar")  driverclass("$classname")  url("$NEFSC_USERS_URL")  user("$myuid") password("$mypwd");


local sql "select * from cams_garfo.CFG_ITIS" ; 
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 

duplicates drop;
destring, replace;
compress;
notes: "`sql'";
save  ${data_main}/commercial/cams_species_keyfile_$vintage_string.dta, replace;

/* Port keyfiles 
CAMS: Port is 
A combined code for state, port and county. Taken with priority from CFDERS -> VTR PORT1 -> PRINC_PORT (permit data). Unknown = 990999. Named ports in VTR are converted to port numbers using the VTR.VLPORTTBL table. 

There are 3 port tables, one in CAMS, one in CFDBS (Dealer database), and one in the trip reports database (VTR)
*/

local sql "select * from CAMS_GARFO.CFG_PORT" ; 



clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/cams_port_$vintage_string.dta, replace;

/* dealer keyfile */


/* cfdbs.Port keyfile 

. */

#delimit ;
local sql "select * from NEFSC_GARFO.CFDBS_port" ; 



clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/cfdbs_port_$vintage_string.dta, replace;




#delimit ;
local sql "select * from NEFSC_GARFO.TRIP_REPORTS_PORT" ; 



clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/trip_reports_port_$vintage_string.dta, replace;











/* Pull dealer information*/


local sql "select * from NEFSC_GARFO.PERMIT_DEALER" ; 


clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/dealer_permit_$vintage_string.dta, replace;


/* DLR_MKT and DLR_GRADE , DLR_DISP */
/*this has market categories, but  I'm not sure if it's the proper support table */


local sql "select * from nefsc_garfo.scbi_species_itis_ne" ; 


clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/dealer_species_itis_ne$vintage_string.dta, replace;



/* GEAR */
/* this table is gone from Oracle
local sql "select * from cams_garfo.CFG_MASTER_GEAR" ; 


clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/cams_master_gear_keyfile_$vintage_string.dta, replace;
 */

local sql "select * from cams_garfo.cfg_NEGEAR" ; 
clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/cams_negear_keyfile_$vintage_string.dta, replace;





local sql "select * from cams_garfo.cfg_vlgear" ; 
clear;
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 
destring, replace;
compress;
notes: "`sql'";

save  ${data_main}/commercial/cams_vlgear_keyfile_$vintage_string.dta, replace;



clear;
local sql "select table_name, column_name, comments from all_col_comments where owner='CAMS_GARFO' and table_name in('CAMS_SUBTRIP','CAMS_LAND','CAMS_ORPHAN_SUBTRIP') order by column_name, table_name" ;
odbc load, exec("`sql' ;") $myNEFSC_USERS_conn;
save  ${data_main}/commercial/cams_keyfile_$vintage_string.dta, replace;


