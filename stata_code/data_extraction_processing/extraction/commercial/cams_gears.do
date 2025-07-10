/* code to read in weekly landings of black sea bass and compute a price  */

# delimit ;
clear;
jdbc connect , jar("$jar")  driverclass("$classname")  url("$NEFSC_USERS_URL")  user("$myuid") password("$mypwd");





local sql "select * from cams_garfo.cfg_negear";
	
/*jdbc load, exec("`sql'") case(lower); */
odbc load, exec("`sql';") $myNEFSC_USERS_conn; 

destring, replace;
compress;

save "${data_main}\commercial\cams_gears_${vintage_string}.dta", replace;

