# =============================================================================
# Script:  hake_daily.R
# Purpose: Pull daily commercial landings for silver hake,
#          aggregated by trip date, state, and species.
# Inputs:  Oracle: cams_garfo.cams_land
# Outputs: data_folder/main/commercial/daily_{vintage_string}.Rds
#          Daily landings and price by species and state (commercial only).
# Notes:   Adapted from /data_extraction_processing/extraction/
#          commercial/sfbsb_daily.R
# 164790	MERLUCCIUS		BLACK WHITING/SILVER HAKE MIX		507	SILVER&OFFSHHAKE MIX
# 164791	MERLUCCIUS BILINEARIS	HAKE,SILVER (WHITING)			509	HAKE,SILVER
# 164793	MERLUCCIUS ALBIDUS	HAKE,OFFSHORE UNC (WHITING,BLACK)	508	HAKE,OFFSHORE
=========================
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
    # silver_hake_itis_codes<- c("164790","164791","164793")

    species_name = case_when(
      itis_tsn == "164790" ~ "BLACK WHITING/SILVER HAKE MIX",
      itis_tsn == "164791" ~ "HAKE,SILVER (WHITING)",
      itis_tsn == "164793" ~ "HAKE,OFFSHORE UNC (WHITING,BLACK)",
      
      TRUE                 ~ NA_character_
    ),
    # price = value / lndlb (landed-weight pounds)
    price = if_else(landings > 0, value / landings, NA_real_)
  ) %>%
  select(-date_trip_str) %>%
  # Stata: order year date_trip value landings state mys price
  relocate(year, date_trip, value, landings, state, species_name, price)

output_path <- here("data_folder", "main", "commercial",
                    glue("hake_daily_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(daily, file = output_path)
message(glue("Saved: {output_path}"))
