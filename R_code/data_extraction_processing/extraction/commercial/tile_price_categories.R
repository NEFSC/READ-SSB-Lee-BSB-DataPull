# =============================================================================
# Script:  tile_price_categories.R
# Purpose: Pull the tile species/grade/market keyfile (tile_sizes) and daily
#          commercial tile landings aggregated by date, itis, market category, and grade.
# Inputs:  Oracle: nefsc_garfo.scbi_species_itis_ne (species-market keyfile)
#                  cams_garfo.cams_land (daily landings)
# Outputs: data_folder/main/commercial/tile_sizes_{vintage_string}.Rds
#            Species-grade-market keyfile with landed-to-live conversion factors.
#            Required input for tile_transactions.R.
#          data_folder/main/commercial/daily_landings_category_{vintage_string}.Rds
#            Daily tile landings by market category and grade, merged with keyfile.
# Notes:   Adapted from /data_extraction_processing/extraction/
#          commercial/bsb_price_categories.R
# =============================================================================


# =============================================================================
# Section 1: Oracle queries
# =============================================================================

# Query 1: Pull species/grade/market keyfile for tile from the NEFSC lookup table.
# cf_lndlb_livlb = conversion factor from landed weight to live weight;
# varies by grade/market (e.g., grade_code 00 = ungraded/gutted, ratio ~1.18;
# grade_code 01/02 = whole/round, ratio ~1.00).
sizes_query <- glue(
  "select nespp4, species_itis as itis_tsn, grade_code, grade_desc,
          market_code, market_desc, cf_lndlb_livlb
   from nefsc_garfo.scbi_species_itis_ne
   where species_itis in ({codes_sql})
   order by nespp4"
)

# Query 2: Daily tile commercial landings aggregated by date, market, and grade.
# Status filter retains only dealer-confirmed records:
#   MATCH              — dealer and VTR records matched
#   DLR_ORPHAN_SPECIES — matching CAMSID but species missing from VTR
#   PZERO              — permit = '000000' (state-permitted vessels)
#   DLR_ORPHAN_TRIP    — dealer trip with no matching VTR trip
landings_query <- glue(
  "select TO_CHAR(trunc(dlr_date), 'MM-DD-YYYY') as dlr_date_str,
          dlr_mkt   as market_code,
          dlr_grade as grade_code,
          itis_tsn,
          sum(lndlb) as landings,
          sum(value) as value,
          sum(livlb) as live
   from cams_garfo.cams_land
   where itis_tsn in ({codes_sql})
     and status in ('MATCH', 'DLR_ORPHAN_SPECIES', 'PZERO', 'DLR_ORPHAN_TRIP')
   group by dlr_mkt, dlr_grade,
            TO_CHAR(trunc(dlr_date), 'MM-DD-YYYY'), itis_tsn"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

tile_sizes      <- dbGetQuery(nova_conn, sizes_query)
daily_landings <- dbGetQuery(nova_conn, landings_query)

dbDisconnect(nova_conn)


# =============================================================================
# Section 2: Process and save tile_sizes keyfile
# =============================================================================

tile_sizes <- tile_sizes %>%
  rename_with(tolower) %>%
  mutate(
    itis_tsn       = as.character(itis_tsn),
    grade_code     = as.character(grade_code),
    market_code    = as.character(market_code),
    cf_lndlb_livlb = as.numeric(cf_lndlb_livlb)
  ) %>%
  distinct()  # Stata: duplicates drop

sizes_path <- here("data_folder", "main", "commercial",
                   glue("tile_sizes_{vintage_string}.Rds"))
if (!dir.exists(dirname(sizes_path))) dir.create(dirname(sizes_path), recursive = TRUE)
saveRDS(tile_sizes, file = sizes_path)
message(glue("Saved: {sizes_path}"))


# =============================================================================
# Section 3: Process daily landings
# =============================================================================

daily_landings <- daily_landings %>%
  rename_with(tolower) %>%
  mutate(
    dlr_date    = as.Date(dlr_date_str, format = "%m-%d-%Y"),
    year        = year(dlr_date),
    month       = month(dlr_date),
    # NOTE: lubridate::week() counts from Jan 1 (week 1 contains Jan 1),
    # matching Stata's week() function behavior.
    week        = week(dlr_date),
    landings    = as.numeric(landings),
    value       = as.numeric(value),
    live        = as.numeric(live),
    itis_tsn    = as.character(itis_tsn),
    grade_code  = as.character(grade_code),
    market_code = as.character(market_code)
  ) %>%
  select(-dlr_date_str)

# price = value / landings (landed-weight pounds, lndlb)
# NOTE: uses lndlb as denominator, unlike tile_transactions.R which uses livlb.
# Both are intentional — different analytical contexts for the two datasets.
daily_landings <- daily_landings %>%
  mutate(price = if_else(landings > 0, value / landings, NA_real_))


# =============================================================================
# Section 4: Merge daily landings with tile_sizes keyfile
# =============================================================================

nrow_pre <- nrow(daily_landings)

# Stata: merge m:1 itis_tsn grade_code market_code using tile_sizes, keep(1 3)
# keep(1 3) = master-only and matched → left_join
tile_sizes_merge <- tile_sizes %>%
  mutate(insizes = 1L)

daily_landings <- daily_landings %>%
  left_join(tile_sizes_merge, by = join_by(itis_tsn, grade_code, market_code)) %>%
  mutate(merge_species_codes = if_else(is.na(insizes), 1L, 3L)) %>%
  select(-insizes)

stopifnot(
  "left_join changed row count — tile_sizes may have duplicate keys" =
    nrow(daily_landings) == nrow_pre
)


# =============================================================================
# Section 5: Save daily landings output
# =============================================================================

landings_path <- here("data_folder", "main", "commercial",
                      glue("daily_tile_landings_category_{vintage_string}.Rds"))
saveRDS(daily_landings, file = landings_path)
message(glue("Saved: {landings_path}"))
message(glue("Rows: {nrow(daily_landings)}, Unmatched: {sum(daily_landings$merge_species_codes == 1)}"))
