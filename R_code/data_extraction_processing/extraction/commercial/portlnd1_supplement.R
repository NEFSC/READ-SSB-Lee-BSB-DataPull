# =============================================================================
# Script:  portlnd1_supplement.R
# Purpose: Pull port-of-landing (portlnd1) data from VTR trip report documents
#          for all trips since 1996.  Supplements or fills gaps in older port
#          landing data.
# Inputs:  Oracle: nefsc_garfo.trip_reports_document
# Outputs: data_folder/main/commercial/portlnd1_supplement_{vintage_string}.Rds
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/portlnd1_supplement.do
#          Recommended downstream merge: 1:1 on permit + tripid + dbyear
#          using update (not update replace) to fill missing portlnd1 values.
# =============================================================================


portlnd_query <- glue(
  "select vessel_permit_num as permit,
          to_char(docid)    as tripid,
          port1_number      as port,
          port1             as portlnd1,
          state1,
          extract(YEAR from DATE_LAND) as dbyear
   from NEFSC_GARFO.TRIP_REPORTS_DOCUMENT
   where extract(YEAR from DATE_LAND) >= 1996
   order by dbyear, permit, tripid"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

portlnd1 <- dbGetQuery(nova_conn, portlnd_query)

dbDisconnect(nova_conn)


portlnd1 <- portlnd1 %>%
  rename_with(tolower) %>%
  mutate(permit = as.character(permit))  # keep as character to preserve leading zeros

output_path <- here("data_folder", "main", "commercial",
                    glue("portlnd1_supplement_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(portlnd1, file = output_path)
message(glue("Saved: {output_path}"))
