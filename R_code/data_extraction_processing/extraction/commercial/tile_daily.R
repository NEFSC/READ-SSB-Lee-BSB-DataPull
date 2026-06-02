# =============================================================================
# Script:  tile_daily.R
# Purpose: Pull daily commercial landings for tilefish,
#          aggregated by trip date, state, and species.
# Inputs:  Oracle: cams_garfo.cams_land
# Outputs: data_folder/main/commercial/daily_{vintage_string}.Rds
#          Daily landings and price by species and state (commercial only).
# Notes:   Adapted from /data_extraction_processing/extraction/
#          commercial/sfbsb_daily.R
#  itis_tsn == "168543" ~ "TILEFISH, BLUELINE",
#  itis_tsn == "168546" ~ "TILEFISH, (GOLDEN TILEFISH)",
#  itis_tsn == "168537" ~ "TILEFISH, UNC",
#  itis_tsn == "168544" ~ "TILEFISH, GOLDFACE",
# =============================================================================
daily_query <- glue(
  "select TO_CHAR(trunc(date_trip), 'MM-DD-YYYY') as date_trip_str,
          itis_tsn,
          sum(nvl(value,   0)) as value,
          sum(nvl(lndlb,   0)) as landings,
          state
   from cams_garfo.cams_land
   where itis_tsn in ({codes_sql})
     and rec = 0
   group by TO_CHAR(trunc(date_trip), 'MM-DD-YYYY'), state, itis_tsn"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

daily <- dbGetQuery(nova_conn, daily_query)

dbDisconnect(nova_conn)


daily <- daily %>%
  rename_with(tolower) %>%
  mutate(
    date_trip    = as.Date(date_trip_str, format = "%m-%d-%Y"),
    year         = year(date_trip),
    landings     = as.numeric(landings),
    value        = as.numeric(value),
    itis_tsn     = as.character(itis_tsn),
    state        = as.factor(state),
    # Human-readable species name (replaces Stata label define / label value)
    # tilefish_itis_codes<- c("168543","168546","168537","168544")

    species_name = case_when(
      itis_tsn == "168543" ~ "TILEFISH, BLUELINE",
      itis_tsn == "168546" ~ "TILEFISH, (GOLDEN TILEFISH)",
      itis_tsn == "168537" ~ "TILEFISH, UNC",
      itis_tsn == "168544" ~ "TILEFISH, GOLDFACE",
      
      TRUE                 ~ NA_character_
    ),
    # price = value / lndlb (landed-weight pounds)
    price = if_else(landings > 0, value / landings, NA_real_)
  ) %>%
  select(-date_trip_str) %>%
  # Stata: order year date_trip value landings state mys price
  relocate(year, date_trip, value, landings, state, species_name, price)

output_path <- here("data_folder", "main", "commercial",
                    glue("tile_daily_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(daily, file = output_path)
message(glue("Saved: {output_path}"))
