# =============================================================================
# Script:  cams_gears.R
# Purpose: Pull the CAMS/GARFO gear code lookup table (cfg_negear).
# Inputs:  Oracle: cams_garfo.cfg_negear
# Outputs: data_folder/main/commercial/cams_gears_{vintage_string}.Rds
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/cams_gears.do
# Author:
# Date:
# =============================================================================


drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

cams_gears <- dbGetQuery(nova_conn, "select * from cams_garfo.cfg_negear")

dbDisconnect(nova_conn)


cams_gears <- cams_gears %>%
  rename_with(tolower)%>%
  mutate(negear=as.numeric(negear),
         mesh_match=as.numeric(mesh_match),
         accsp_category_code=as.numeric(accsp_category_code)

)

output_path <- here("data_folder", "main", "commercial",
                    glue("cams_gears_{vintage_string}.Rds"))
if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
saveRDS(cams_gears, file = output_path)
message(glue("Saved: {output_path}"))
