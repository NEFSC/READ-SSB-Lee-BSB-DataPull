********************************************************************************
* BSB_dersource_investigations 
* Purpose: 	extract landings by dersource and make some charts and graphs.
********************************************************************************
/*
This is a a bit of quality assurance. landings come into the dealer databases from a variety of sources

*/

# delimit ;
clear;

local sql "select state, nespp4, dersource, year, sum(spplndlb) as landings, sum(sppvalue) as value from nefsc_garfo.cfders_all_years
    where nespp3=335 and year>=2000
	group by state, nespp4, dersource, year" ;
	
clear;	

odbc load, exec("`sql'; ")  $myNEFSC_USERS_conn;

destring, replace;
compress;
format year %4.0f;
gen price=value/landings


replace landings=landings/1000000
preserve
keep if year>=2010
collapse (sum) landings value, by(state dersource)



graph bar (asis) landings, over(dersource) asyvars stack over(state) legend(rows(3)) ytitle("Millions of pounds")
graph export "state_landings_by_dersource.png", as(png)

graph bar (asis) landings, over(state) asyvars stack over(dersource, label(angle(45))) legend(rows(3)) ytitle("Millions of pounds")

graph export "${exploratory}/dersource_landings_by_state.png", as(png)

restore


preserve
collapse (sum) landings value, by(year dersource)




graph bar (asis) landings, over(dersource) asyvars stack over(year, label(angle(45))) legend(rows(3)) ytitle("Millions of pounds")
graph export "${exploratory}/dersource_landings_over_time.png", as(png)

