/* code to read in daily landings of black sea bass and summer flounder*/
#delimit ;

clear ;
*jdbc connect , jar("$jar")  driverclass("$classname")  url("$NEFSC_USERS_URL")  user("$myuid") password("$mypwd");



local sql "select year, date_trip, itis_tsn, sum(nvl(value,0)) as value, sum(nvl(lndlb,0)) as landings, state from cams_land 
    where itis_tsn in ('167687','172735') and rec=0 
	group by year, date_trip, state, itis_tsn
    order by itis_tsn, state, year, date_trip" ;


odbc load, exec("`sql'")  $myNEFSC_USERS_conn;


destring, replace;
compress;
format year %4.0f;

encode state, gen(mys);

label define itis 172735 "Summer Flounder" 167687 "Black Sea Bass";

label value itis_tsn itis;
gen price=value/landings;
order year date_trip value landings state mys price;


save "${data_main}\commercial\daily_${vintage_string}.dta", replace;