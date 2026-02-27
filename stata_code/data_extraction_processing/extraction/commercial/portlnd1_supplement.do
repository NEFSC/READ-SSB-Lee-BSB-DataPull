#delimit ;
/* Pull portlnd1 and other data for mergeing from TRIP_REPORTS_DOCUMENT
We already have portlnd1 through 2022. This pulls all. 
The earlier data had some data cleaning done on portlnd1. 

As a first pass, I would probably do a

merge 1:1 permit tripid dbyear using portlnd1_supplement, update  

and NOT

merge ... , update replace


 */
clear;



local sql "select vessel_permit_num as permit, to_char(docid) as tripid, port1_number as port, port1 as portlnd1, state1, extract(YEAR from DATE_LAND) as dbyear 
    from NEFSC_GARFO.TRIP_REPORTS_DOCUMENT
    where extract(YEAR from DATE_LAND) >=1996
    order by dbyear, permit, tripid " ;
		
clear;

odbc load, exec("`sql'")  $myNEFSC_USERS_conn;
destring permit, replace;

save ${data_main}\commercial\portlnd1_supplement_${vintage_string}.dta, replace ;

