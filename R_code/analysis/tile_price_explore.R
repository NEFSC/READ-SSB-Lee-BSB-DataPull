# Purpose Explore tilefish price variability


library(tidyverse)
library(here)

here::i_am("READ-SSB-Lee-BSB-DataPull/R_code/analysis/tile_price_explore.R")

tile_landings_all <- readRDS(here("data_folder","main","commercial","tile_landings_all_2026-06-09.Rds"))

# keep just NY
ny<-tile_landings_all %>% 
  dplyr::filter(state=="NY") %>%
  dplyr::filter(year>=2002 & year<=2025)

# pull the top 3 hullids
top3_hullid<-ny %>%
  group_by(hullid) %>%
  summarise(tl=sum(lndlb)) %>%
  arrange(desc(tl)) %>%
  slice_head(n=3) %>%
  pull(hullid)

# filter the dataset to keep just the top 3. Also filter MATCH
top_3_ny <-ny %>%
  dplyr::filter(hullid %in% top3_hullid) %>%
  dplyr::filter(status =="MATCH") %>%
  mutate(price=value/lndlb)
  

# compute yearly average prices by market code for each hullid-dlrid-year combination in the top 3 hullid
 yearly_top3 <-top_3_ny %>%
   group_by(hullid,year, dlrid, market_code) %>%
   summarise(sum_landing=sum(lndlb, na.rm=TRUE),
           sum_value=sum(value),na.rm=TRUE) %>%
   mutate(price=sum_value/sum_landing) %>%
   ungroup()
 
 # plot some 
 
#  plot 1 -- hard to see, but there's quite some variability for the one of the hullids
 ggplot(top_3_ny %>% filter(hullid==top3_hullid[1]), aes(x=as.factor(year), y=price, fill=market_code)) + 
   geom_boxplot(aes(weight=lndlb))# + 
#   facet_wrap(~hullid, scale="free")
 
 # look at it another way
 ggplot(top_3_ny %>% filter(hullid==top3_hullid[1]), aes(x=market_code, y=price, fill=market_code)) + 
   geom_boxplot(aes(weight=lndlb)) + 
 facet_wrap(~year, scale="free")
 
 # all 3 of the top
 ggplot(top_3_ny, aes(x=market_code, y=price, fill=as.factor(hullid))) + 
   geom_boxplot(aes(weight=lndlb)) + 
   facet_wrap(~year, scale="free")

 #takeaway -- there's price variation for these 3 big sellers (hullids) in NY
 
 
 
