# =============================================================================
# Script:  bsb_transactions.R
# Purpose: Extract transaction-level commercial Black Sea Bass landings from
#          CAMS/GARFO Oracle databases, compute price per live-weight pound,
#          and merge in species/market-category metadata.
# Inputs:  Oracle: cams_garfo.cams_land, cams_garfo.cams_subtrip (live query)
#          File:   data_folder/main/commercial/bsb_sizes_{vintage_string}.Rds
#                  (grade/market keyfile; produced by bsb_price_categories.R)
# Outputs: data_folder/main/commercial/landings_all_{vintage_string}.Rds
#          Transaction-level BSB commercial landings with prices and
#          market-category metadata. One row per dealer report record.
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/bsb_transactions.do
# Author:
# Date:
# =============================================================================

library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::arrange)

here::i_am("R_code/data_extraction_processing/extraction/commercial/bsb_transactions.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# =============================================================================
# Section 1: Oracle connection and data pull
# =============================================================================

# SQL joins dealer records (cams_land) to subtrip records (cams_subtrip) via
# a LEFT JOIN on camsid + subtrip number.  All dealer records are retained;
# trip-level fields (gear, area, coordinates, vessel length, sail/land dates)
# are attached where a matching subtrip record exists.
#
# Filters applied in SQL:
#   itis_tsn = '167687'  →  Black Sea Bass (Centropristis striata) ITIS TSN
#   rec = 0              →  commercial trips only (rec = 1 flags recreational)
#
# No year-range filter is applied — the full history of BSB commercial
# landings is extracted, consistent with the Stata original.

sql_query <- glue(
  "select st.docid, st.subtrip, st.area, st.negear, st.mesh_cat,
          st.record_sail, st.record_land, st.ves_len,
          cl.dlr_stid, cl.dlr_cflic, cl.camsid, cl.permit, cl.hullid,
          cl.year, cl.month, cl.week, cl.dlr_date,
          cl.dlr_mkt   as market_code,
          cl.dlr_grade as grade_code,
          cl.dlrid, cl.itis_tsn, cl.state, cl.port,
          cl.lndlb, cl.value, cl.livlb,
          cl.status, cl.dlr_source, cl.rec,
          st.lat_dd, st.lon_dd
   from cams_garfo.cams_land cl
   LEFT JOIN cams_garfo.cams_subtrip st
       on cl.camsid  = st.camsid
      and cl.subtrip = st.subtrip
   where cl.itis_tsn = '167687'
     and cl.rec = 0"
)

# Establish Oracle connection.  Credentials (id, novapw, nefscusers.connect.string)
# should be available in the session via keyring or .Rprofile.
# See documentation/project_logistics.md for credential setup instructions.
drv       <- dbDriver("Oracle")
nova_conn <- dbConnect(drv, id, password = novapw, dbname = nefscusers.connect.string)

landings_all <- dbGetQuery(nova_conn, sql_query)

dbDisconnect(nova_conn)


# =============================================================================
# Section 2: Type cleanup and naming conventions
# =============================================================================

# Lower-case all column names (ROracle returns Oracle identifiers in upper case).
landings_all <- landings_all %>%
  rename_with(tolower)

# ROracle maps Oracle NUMBER columns to numeric and VARCHAR to character
# automatically, but we coerce key columns explicitly to be safe.
# NOTE: Stata uses destring,replace for the same purpose after ODBC load.
# itis_tsn is Oracle VARCHAR — kept as character here for consistent join keys.
landings_all <- landings_all %>%
  mutate(
    year        = as.integer(year),
    month       = as.integer(month),
    week        = as.integer(week),
    lndlb       = as.numeric(lndlb),
    livlb       = as.numeric(livlb),
    value       = as.numeric(value),
    negear      = as.numeric(negear),
    ves_len     = as.numeric(ves_len),
    itis_tsn    = as.character(itis_tsn),   # keep as character; used as join key
    grade_code  = as.character(grade_code),
    market_code = as.character(market_code)
  )


# =============================================================================
# Section 3: Construct price variable
# =============================================================================

# price = value / livlb  (dollars per live-weight pound)
#
# Live weight (livlb) is used as the denominator rather than landed weight
# (lndlb).  This makes prices more comparable across market categories because
# the landed-to-live weight conversion ratio (cf_lndlb_livlb, in the bsb_sizes
# keyfile) differs by grade and market category — e.g., gutted vs. round weight.
#
# NOTE: Stata gen price=value/livlb produces missing (.) for division by zero
# or missing livlb.  In R, 0-division yields Inf and missing-division yields NaN.
# We guard explicitly: price is NA_real_ when livlb is 0 or NA.
# Live price is intentional for the black sea bass project. It also doesn't substantively matter, because
# all market catgories for bsb have live pounds=landed pounds

landings_all <- landings_all %>%
  mutate(price = if_else(livlb > 0, value / livlb, NA_real_))


# =============================================================================
# Section 4: Merge in species/market-category keyfile (bsb_sizes)
# =============================================================================

# bsb_sizes is the species-grade-market lookup table produced by
# bsb_price_categories.do (R equivalent: bsb_price_categories.R when ported).
# Fields added: nespp4, grade_desc, market_desc, cf_lndlb_livlb.
#

bsb_sizes <- readRDS(here("data_folder", "main", "commercial",
                          glue("bsb_sizes_{vintage_string}.Rds")))

# Ensure join keys are character in the lookup table, matching landings_all.
bsb_sizes <- bsb_sizes %>%
  rename_with(tolower) %>%
  mutate(
    itis_tsn    = as.character(itis_tsn),
    grade_code  = as.character(grade_code),
    market_code = as.character(market_code),
    insizes=1
  )

nrow_pre <- nrow(landings_all)

# Stata: merge m:1 itis_tsn grade_code market_code using bsb_sizes, keep(1 3)
#   m:1      = many landings rows per (itis_tsn, grade_code, market_code) key;
#              one lookup row per key → left_join
#   keep(1 3) = keep master-only (unmatched) and matched rows → left_join
#   Stata _merge codes: 1 = master only (no match in keyfile), 3 = matched
landings_all <- landings_all %>%
  left_join(bsb_sizes, by = join_by(itis_tsn, grade_code, market_code))

# Recreate the Stata _merge indicator (renamed merge_species_codes).
# Sentinel: created column insizes=1; NA after join → no match.
#   1 = master only (transaction record with no matching keyfile entry)
#   3 = matched (transaction record found in keyfile)
landings_all <- landings_all %>%
  mutate(merge_species_codes = if_else(is.na(insizes), 1L, 3L)) %>%
 select(-insizes)

# Row count must not change: left_join preserves all master rows.
# If this fires, bsb_sizes has duplicate keys — investigate before proceeding.
nrow_post <- nrow(landings_all)
stopifnot(
  "left_join changed row count — bsb_sizes may have duplicate keys" =
    nrow_pre == nrow_post
)


# =============================================================================
# Section 5: Save output
# =============================================================================

output_dir  <- here("data_folder", "main", "commercial")
output_file <- glue("landings_all_{vintage_string}.Rds")
output_path <- file.path(output_dir, output_file)

# Create the output directory if it does not yet exist.
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

saveRDS(landings_all, file = output_path)

message(glue("Saved:   {output_path}"))
message(glue("Rows:    {nrow(landings_all)}"))
message(glue("Columns: {ncol(landings_all)}"))
message(glue("Unmatched to bsb_sizes (merge_species_codes == 1): ",
             "{sum(landings_all$merge_species_codes == 1)}"))
