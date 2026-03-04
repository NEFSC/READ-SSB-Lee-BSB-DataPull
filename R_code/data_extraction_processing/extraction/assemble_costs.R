################################################################################
################################################################################
################################################################################
# Construct cost-per-day. This was initially developed for the Extending structural models paper, but it's pretty general.
# The Trip_costs data are on the network. These contain predicted costs and actual costs for observed trips.  
#     There is a CAMSID, but because CAMSID is not stable across CAMS model runs, we need to merge on the permit-docid.  
#     We can get this by pulling apart the CAMSID
# We want to get daily costs for the extending structural paper, which means we need to pull trip length data from either CAMS or VESLOG
# We also want costs by gear.

# Inputs:
# Trip_costs excel sheet-- Use this in two ways. 
#   A. Use the "trip_cost_2024_dol" and the "observed_cost_dummy" columns to construct observed costs, by gear type and year. 
#   B. Use the "trip-cost_winsor_2024_dol" to construct predicted (and observed) costs by hullid and year. 
# Requires oracle connection to pull CAMS data



# Outputs: 
# costs_per_hullid -- a dataframe that contains trip costs by hullid
# observed_costs_per_day -- a dataframe that contains average trip costs by "mygear and fishing_year"





library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("readxl")
library("lubridate")
library("stats")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(lubridate::year)
conflicts_prefer(lubridate::month)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::arrange)

here::i_am("R_code/data_extraction_processing/extraction/assemble_costs.R")

vintage_string<-format(Sys.Date())

year_start<-2010

################################################################################
########################Begin Data in from Oracle#################################
################################################################################





# Query to pull out the CAMSID, SUBTRIP, and total value by subtrip
subtrip_query<-glue("select CAMSID, hullid, subtrip, sum(nvl(value,0)) as value from cams_garfo.cams_land
    where year>={year_start} and permit<>000000
    group by CAMSID, subtrip, hullid
    order by camsid, subtrip, hullid, value")

# Query to pull out the CAMSID, SUBTRIP, and NEGEAR
gear_code_query<-glue("select camsid, subtrip, negear, record_sail, record_land, date_trip from cams_garfo.cams_subtrip
    where year>={year_start} and permit<>000000")


drv<-dbDriver("Oracle")
nova_conn<-dbConnect(drv, id, password=novapw, dbname=tns_alias)

# Get the data
subtrips<-dbGetQuery(nova_conn, subtrip_query)
gear_codes<-dbGetQuery(nova_conn, gear_code_query)

dbDisconnect(nova_conn)


################################################################################
########################End Data in from Oracle#################################
################################################################################



################################################################################
########################Begin Data in from network#################################
################################################################################

trip_cost_path<-file.path("//nefscdata","Trip_Costs","Trip_Cost_Estimates","2010_2024")
trip_cost_filename<-"2010_2024.xlsx"
trip_costs<-read_xlsx(file.path(trip_cost_path,trip_cost_filename), sheet="2010-2015")
trip_costs2<-read_xlsx(file.path(trip_cost_path,trip_cost_filename), sheet="2016-2024")
trip_costs<-bind_rows(trip_costs,trip_costs2)
  rm(trip_costs2)

trip_costs <-trip_costs %>%
  rename_with(tolower) 


################################################################################
########################End Data in from Network#################################
################################################################################



################################################################################
########################Data tidyups#################################
################################################################################
subtrips<-subtrips %>%
  rename_with(tolower) 

gear_codes<-gear_codes %>%
  rename_with(tolower) 

# Pull out year and month from the date_trip field

gear_codes<-gear_codes %>%
  mutate(year=year(date_trip),
         month=month(date_trip)) 

#construct groundfish fishing year
gear_codes<-gear_codes %>%
  mutate(fishing_year=ifelse(month>=5,year, year-1) ) %>%
  select(-c(month,year, date_trip))

trip_costs<-trip_costs %>%
  rename_with(tolower)

#backup, for troublshooting as you go along
trip_costs_bak<-trip_costs
gear_codes_bak<-gear_codes
subtrips_bak<-subtrips

# Costs -- parse CAMSID to get permit, date, and docid
#I'm using _tc to flag that the date is coming from parsing the camsid in the trip cost data. 
trip_costs<-trip_costs %>%
  separate_wider_delim(camsid, delim="_", names=c("permit", "date_camsid_tc", "docid"), too_many="merge", cols_remove=FALSE) 
  
# error handle.  Stop if you somehow have any rows that have no permit.
stopifnot(nrow(trip_costs %>% filter(permit=="000000"))==0)
length(unique(subtrips$camsid))

#pick 1 row.  
subtrips2<- subtrips %>%
  group_by(camsid) %>%
  arrange(desc(value), .by_group=TRUE) %>%
  slice_head(n=1) %>%
  ungroup()


length(unique(subtrips2$camsid))
length(subtrips2$camsid)

#Make sure you don't lose any camsids.
stopifnot(length(unique(subtrips$camsid))==length(subtrips2$camsid) )

# Make sure you have 1 row per camsid
max_check<-subtrips2 %>%
  group_by(camsid) %>%
  mutate(counter=n()) %>%
  ungroup() %>%
  summarise(counter=max(counter)) %>%
  pull(counter)

stopifnot(max_check==1)


nrow_pre<-nrow(subtrips2)
# left join to gear-codes 
subtrips2<-subtrips2 %>%
  left_join(gear_codes, by=join_by(camsid==camsid, subtrip==subtrip))
nrow_post<-nrow(subtrips2)

# Data quality checks
# make sure you don't gain or lose rows.
stopifnot(nrow_pre==nrow_post)
# all camsid in subtrips2 are unique
stopifnot(length(unique(subtrips2$camsid))==length(subtrips2$camsid) )

# just negear, hullid, record_sail, record_land 
subtrips2<-subtrips2 %>%
  select(camsid, hullid, negear, record_sail, record_land, fishing_year)

#I'm using _st to flag that the date is coming from parsing the camsid in the cams_subtrip data. 
subtrips2<-subtrips2 %>%
  separate_wider_delim(camsid, delim="_", names=c("permit", "date_camsid_st", "docid"), too_many="merge", cols_remove=FALSE) 

# remove rows where there is not docid. These are trips by non-federally permitted vessels that will not merge to the trip-cost predictions
subtrips2<-subtrips2 %>%
  filter(docid!="000000") %>%
  rename(camsid_st=camsid)



###########Merge

# merge gears and hullid to trip_costs
trip_costs <- trip_costs %>%
  rename(camsid_tc=camsid) %>%
  left_join(subtrips2 , by=join_by(permit==permit, docid==docid)) 


#Construct TRIP LENGTH (DAYS)
trip_costs<-trip_costs %>%
  filter(!is.na(camsid_st)) %>%
  mutate(triplength_days=as.double(difftime(record_land,record_sail, units="days") ) )

# set day trips to 1 day in length
trip_costs<-trip_costs %>%
  mutate(triplength_days=ifelse(triplength_days<=1,1,triplength_days)) %>%
  mutate(negear=as.numeric(negear))


# deal with negear
# This may or may not be your preferred way to bin negears

trip_costs <- trip_costs%>%
  mutate(
    mygear = case_when(
      negear %in% c(999) ~ "Unknown",
      negear %in% c(132, 400) ~ "Dredge",
      between(negear, 381, 387) ~ "Dredge",
      negear %in% c(80, 140, 141, 142, 143, 240, 260, 270, 320, 321, 322, 323) ~ "PotTrap",
      between(negear, 180, 217) ~ "PotTrap",
      between(negear, 300, 301) ~ "PotTrap",
      negear %in% c(70, 71, 160, 360) ~ "Seine",
      between(negear, 120, 124) ~ "Seine",
      negear %in% c(500, 520) ~ "Gillnet",
      between(negear, 100, 117) ~ "Gillnet",
      negear %in% c(150, 170, 171, 350, 351, 353, 370, 450) ~ "Trawl",
      between(negear, 50, 59) ~ "Trawl",
      negear %in% c(10, 20, 21, 30, 34, 40, 420, 60, 62, 65, 66, 67, 250, 251, 330, 
                    340, 380, 414, 90, 410) ~ "LineHand",
      between(negear, 220, 230) ~ "LineHand",
      TRUE ~ NA_character_
    )
  )

# all geared up?
stopifnot(sum(is.na(trip_costs$mygear))==0)
test<-trip_costs %>%
  filter(is.na(mygear))

################################################################################
################################################################################
# Observed costs per day, by geartype
################################################################################
################################################################################

# Keep just the rows where we observe a trip.

observed_costs_per_day<-trip_costs %>%
  filter(observed_cost_dummy==1) 

# compute cost per day using trip cost
# nominal_cost_per_dayUW (Unweighted) -- just a straight mean
# nominal_cost_per_dayW (Weighted) -- weight each trip by the trip length (in days)
observed_costs_per_day<-observed_costs_per_day %>%
  mutate(nominal_cost_per_day=trip_cost_nominaldols/triplength_days)  %>%
  group_by(mygear, fishing_year) %>%
  summarise(nominal_cost_per_dayUW=mean(nominal_cost_per_day),
            nominal_cost_per_dayW=weighted.mean(nominal_cost_per_day,triplength_days),
            total_costs=sum(trip_cost_nominaldols),
            total_days=sum(triplength_days),
            trips=n())
observed_costs_per_day<-observed_costs_per_day %>%
  filter(fishing_year>=2010 & fishing_year<=2024)
write_rds(observed_costs_per_day, file=here("data_folder","main","commercial", glue("observed_costs_per_day_{vintage_string}.Rds")))
write_dta(observed_costs_per_day, path=here("data_folder","main","commercial", glue("observed_costs_per_day_{vintage_string}.dta")))

# Filter to trawl and gillnet?
# observed_costs_per_day2<-observed_costs_per_day %>%
#  filter(mygear %in% c("Trawl","Gillnet"))
# left_join to some data by=join_by(fleet==mygear, fishing_year==fishing_year)



################################################################################
################################################################################
# Costs per hullid, both observed and predicted. 
################################################################################
################################################################################

#  We use the winsorized cost column, because the prediction model sometimes generates some major outliers.
#  Like the previous section, compute trip-level cost per day, then 
#  compute the hullid unweigthed mean, hullid weighted mean (by trip days)
costs_per_hullid<-trip_costs %>%
  mutate(nominal_cost_per_day=trip_cost_nominaldols_winsor/triplength_days)  %>%
  group_by(hullid,fishing_year) %>%
  summarise(nominal_cost_per_dayUW=mean(nominal_cost_per_day),
            nominal_cost_per_dayW=weighted.mean(nominal_cost_per_day,triplength_days),
            total_costs=sum(trip_cost_nominaldols_winsor),
            total_days=sum(triplength_days),
            trips=n()) %>%
  filter(is.na(hullid)==FALSE)

costs_per_hullid<-costs_per_hullid %>%
  filter(fishing_year>=2010 & fishing_year<=2024)

write_rds(costs_per_hullid, file=here("data_folder","main","commercial", glue("costs_per_hullid_{vintage_string}.Rds")))
write_dta(costs_per_hullid, path=here("data_folder","main","commercial", glue("costs_per_hullid_{vintage_string}.dta")))

# Filter to trawl and gillnet?
# left_join to some data by=join_by(hullid==hullid, fishing_year==fishing_year)


#write out the raw trip-cost data
write_rds(trip_costs, file=here("data_folder","main","commercial", glue("raw_trip_costs_{vintage_string}.Rds")))
write_dta(trip_costs, path=here("data_folder","main","commercial", glue("raw_trip_costs{vintage_string}.dta")))


