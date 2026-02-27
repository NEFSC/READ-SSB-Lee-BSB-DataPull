

/* code to read in daily landings of black sea bass and summer flounder*/
#delimit ;

clear ;
*jdbc connect , jar("$jar")  driverclass("$classname")  url("$NEFSC_USERS_URL")  user("$myuid") password("$mypwd");



local sql "select TO_CHAR(trunc(date_trip),'MM-DD-YYYY') as date_trip_str, itis_tsn, sum(nvl(value,0)) as value, sum(nvl(lndlb,0)) as landings, state from cams_garfo.cams_land 
    where itis_tsn in ('167687','172735') and rec=0 
	group by TO_CHAR(trunc(date_trip),'MM-DD-YYYY'), state, itis_tsn" ;


odbc load, exec("`sql'")  $myNEFSC_USERS_conn;


gen date_trip=date(date_trip_str,"MDY");
format date_trip %td;
gen year=year(date_trip);


destring, replace;
compress;
format year %4.0f;

encode state, gen(mys);

label define itis 172735 "Summer Flounder" 167687 "Black Sea Bass";

label value itis_tsn itis;
gen price=value/landings;
order year date_trip value landings state mys price;


save "${data_main}\commercial\daily_${vintage_string}.dta", replace;