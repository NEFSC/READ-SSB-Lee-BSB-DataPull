********************************************************************************
* permit_characteristics_extractions 
* THIS BIT OF CODE IS USED TO EXTRACT data from the valid_fishery table. 
* Fishery_ID: Identifier
* Plan: Fishery Management Plan
* Cat: category
* Descr: description
* Moratorium_fishery : True=Limited Access, False=Open Access
* Mandatory_reporting: True= requires VTRs, False=does not.
* Per_yr_start_date: The day that the fishing year starts.
* Per_yr_end_date: The day it ends.
* Fishery_type: commercial or recreational

* When the Herring Plan was open access, it was "Plan=HER", When it went to LA it became "Plan=HRG", and HRG_D became the open access category
* Similar things happend with Scallop (SC splits into SC and LGC)

********************************************************************************

#delimit;

global lastyr 2025;

clear;
odbc load, exec("select fishery_id, plan, cat, permit_year as ap_year, descr, moratorium_fishery, mandatory_reporting, per_yr_start_date, per_yr_end_date, fishery_type from nefsc_garfo.permit_valid_fishery vf  where 
	permit_year between 1996 and $lastyr
    order by plan, cat, permit_year;")  $myNEFSC_USERS_conn;
    destring, replace;
    renvars, lower;

	
replace per_yr_start_date=dofc(per_yr_start_date);
replace  per_yr_end_date=dofc(per_yr_end_date);

format per_yr_start_date per_yr_end_date %td;
save ${data_main}/commercial/vps_valid_fishery$today_date_string.dta, replace ;




