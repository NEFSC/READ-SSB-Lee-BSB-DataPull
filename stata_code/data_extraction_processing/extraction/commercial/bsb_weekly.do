********************************************************************************
* bsb_weekly.do 
* Purpose: 	code to read in weekly landings of black sea bass and compute a price.   

********************************************************************************




# delimit ;
clear ;

/*   */

/*jdbc connect , jar("$jar")  driverclass("$classname")  url("$NEFSC_USERS_URL")  user("$myuid") password("$mypwd") */




local sql "select TO_CHAR(trunc(dlr_date),'MM-DD-YYYY') as dlr_date_str, sum(value) as value, sum(lndlb) as landings, state from cams_garfo.cams_land 
	where itis_tsn='167687' and 
	rec=0 
	group by TO_CHAR(trunc(dlr_date),'MM-DD-YYYY'), state" ;
/*jdbc load, exec("`sql'") case(lower); */

odbc load, exec("`sql';") $myNEFSC_USERS_conn ;



gen dlr_date=date(dlr_date_str,"MDY");
format dlr_date %td;
gen year=year(dlr_date);
gen week=week(dlr_date);



destring, replace ;
compress; 
format year %4.0f ;
format week %02.0f ;

encode state, gen(mys);

gen weekly_date=yw(year, week);
format weekly_date %tw;

collapse (sum) landings value, by(mys weekly_date);
tsset mys weekly_date;


gen price=value/landings;

save "${data_main}/commercial/weekly_landings_${vintage_string}.dta", replace;