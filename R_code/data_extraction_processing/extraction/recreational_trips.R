###############################################################################
# Purpose: 	Extract Market Category Data to look for suitable species and stocks to generalize 

# Requirements:
# Connection to Oracle

# Inputs:
#  - None


# Outputs:
#  - landings dataset
#  - grade keyfile 
#  - market category keyfile

###############################################################################  


library("ROracle")
library("glue")
library("tidyverse")
library("haven")
library("here")

here::i_am("R_code/data_extraction_processing/extraction/recreational_trips.R")

vintage_string<-format(Sys.Date())

year_start<-2000
year_end<-2024

#Set up the oracle connection
drv<-dbDriver("Oracle")
nova_conn<-dbConnect(drv, id, password=novapw, dbname=tns_alias)

# Get angler trips, by docid from trip reports. Pull along YEAR.
angler_trips<-glue("select VESSEL_PERMIT_NUM as permit, docid, extract(YEAR FROM DATE_SAIL) as year, sum(nvl(nanglers,0)) as anglers from NEFSC_GARFO.TRIP_REPORTS_DOCUMENT where 
	(tripcatg between 2 and 3) and 
	docid in (select distinct docid from NEFSC_GARFO.TRIP_REPORTS_IMAGES where GEARCODE='HND') and
	extract(YEAR FROM DATE_SAIL) BETWEEN {year_start} and {year_end}
                   group by VESSEL_PERMIT_NUM, docid,extract(YEAR FROM DATE_SAIL)")

angler_trips<-dbGetQuery(nova_conn, angler_trips)

dbDisconnect(nova_conn)



# Add costs
# These costs come from the rec expenditure survey
# https://github.com/NEFSC/READ-SSB-Lee-RFAdataset/blob/master/documentation/input_data_docs/For-Hire_Fee.xlsx
costs<-c(58.35,58.92,59.49,60.06,60.63,61.19, 61.76,62.33, 62.90,63.47,64.03,73.92, 83.80, 93.68, 103.56, 113.44, 116.15, 118.86,121.57,124.28,126.99,129.69,132.40, 135.11,137.82,140.53,143.24)
years<-1996:2022

rec_trip_expenditures <- data.frame(year = years, rec_cost = costs)

# Tack on 2023 and 2024 by adjusting the 2022.
extra_years<-2023:2024
imp_costs<-c(306.996/296.963, 315.233/296.963)
imp_costs<-imp_costs*costs[length(costs)]    

imp_rec_trip_expenditures <- data.frame(year = extra_years, rec_cost = imp_costs)
rec_trip_expenditures<-rbind(rec_trip_expenditures,imp_rec_trip_expenditures)
       
# GDP Deflators for scaling
# scalar C2022=296.963;
# scalar C2023=306.996;
# scalar C2024=315.233;


# rename to lower
angler_trips <- angler_trips %>%
  rename_with(tolower) %>%
  arrange(permit, year, docid)

angler_trips<-angler_trips %>%
  left_join(rec_trip_expenditures, by=join_by(year==year))%>%
  mutate(angler_expenditures=rec_cost*anglers)

write_rds(angler_trips, file=here("data_folder","main","recreational",glue("angler_trips_{vintage_string}.Rds")))
haven::write_dta(angler_trips, path=here("data_folder","main","recreational",glue("angler_trips_{vintage_string}.dta")))

