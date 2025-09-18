********************************************************************************
* observer_fuel_prices 
* Purpose: 	pull fuel prices from the observer data
********************************************************************************


#delimit ;
local date: display %td_CCYY_NN_DD date(c(current_date), "DMY");
global today_date_string = subinstr(trim("`date'"), " " , "_", .);

pause on;

clear;

/* costs*/
odbc load,  exec("select ob.datesail, ob.port, ob.fuelgal, ob.fuelprice, po.portnm, po.stateabb, po.county from obtrp ob, port po where 
year>=2004 and fuelprice is not null and po.port=ob.port;")  $myNEFSC_USERS_conn;

drop if inlist(stateabb,"NK");



replace datesail=dofc(datesail);
format datesail %td ;
save "${data_raw}/raw_fuel_prices_$today_date_string.dta", replace;
gen monthly=mofd(datesail);
drop if fuelgal==.;

preserve ;
collapse (mean) wfuelprice=fuelprice [fweight=fuelgal], by(stateabb monthly);
tempfile t1 ;
save `t1', replace; 
restore;

collapse (mean) fuelprice (sum) fuelgal (count) nobs=fuelgal, by(stateabb monthly);
 
 merge 1:1 stateabb monthly using `t1' ;
 assert _merge==3;
 drop _merge;

format monthly %tm;


save "${data_main}/monthly_state_fuelprices_$today_date_string.dta", replace;
