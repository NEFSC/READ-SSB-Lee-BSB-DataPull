# =============================================================================
# Script:  bsb_dersource_investigations.R
# Purpose: QA investigation of BSB commercial landings by data source
#          (dersource field in CFDERS dealer records).  Produces three
#          exploratory stacked bar charts.
# Inputs:  Oracle: nefsc_garfo.cfders_all_years
# Outputs: images/exploratory/state_landings_by_dersource.png
#          images/exploratory/dersource_landings_by_state.png
#          images/exploratory/dersource_landings_over_time.png
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          commercial/bsb_dersource_investigations.do
#          Uses NESPP3 = 335 (NOAA Northeast species code for BSB), NOT the
#          ITIS TSN 167687 used elsewhere.  cfders_all_years is a NEFSC dealer
#          database table; the CAMS tables are not used here.
#          No data file is saved (consistent with the Stata original).
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

here::i_am("R_code/data_extraction_processing/extraction/commercial/bsb_dersource_investigations.R")

source(here("R_code", "project_logistics", "R_paths_libraries.R"))

vintage_string <- format(Sys.Date())


# nespp3 = 335 is the NOAA Northeast Species/Product code for Black Sea Bass.
# This is distinct from the ITIS TSN 167687 used in all CAMS-based scripts.
dersource_query <- glue(
  "select state, nespp4, dersource, year,
          sum(spplndlb) as landings,
          sum(sppvalue) as value
   from nefsc_garfo.cfders_all_years
   where nespp3 = 335
     and year >= 2000
   group by state, nespp4, dersource, year"
)

drv       <- dbDriver("Oracle")
nova_conn <- eval(nefscdb_con)

dersource_data <- dbGetQuery(nova_conn, dersource_query)

dbDisconnect(nova_conn)


dersource_data <- dersource_data %>%
  rename_with(tolower) %>%
  mutate(
    year     = as.integer(year),
    landings = as.numeric(landings),
    value    = as.numeric(value),
    # price = value / lndlb on original scale, before any unit conversion
    price    = if_else(landings > 0, value / landings, NA_real_)
  )

# Ensure image output directory exists
img_dir <- here("images", "exploratory")
if (!dir.exists(img_dir)) dir.create(img_dir, recursive = TRUE)


# =============================================================================
# Chart 1 & 2: 2010-present, by state and dersource (two views)
# Stata: preserve; keep if year >= 2010; collapse ..., by(state dersource); ...graphs...; restore
# =============================================================================

agg_state_dersource <- dersource_data %>%
  filter(year >= 2010) %>%
  group_by(state, dersource) %>%
  summarise(
    landings = sum(landings, na.rm = TRUE),
    value    = sum(value,    na.rm = TRUE),
    .groups  = "drop"
  )

# Chart 1: stacked by dersource, x = state
# Stata: graph bar (asis) landings, over(dersource) asyvars stack over(state)
# Landings divided by 1e6 for display only; data saved at original scale.
p1 <- ggplot(agg_state_dersource,
             aes(x = state, y = landings / 1e6, fill = dersource)) +
  geom_col() +
  labs(
    x     = "State",
    y     = "Millions of pounds",
    fill  = "Data source",
    title = "BSB landings by state and dealer data source (2010-present)"
  ) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(img_dir, "state_landings_by_dersource.png"),
       plot = p1, width = 9, height = 6, dpi = 150)
message("Saved: state_landings_by_dersource.png")

# Chart 2: stacked by state, x = dersource
# Stata: graph bar (asis) landings, over(state) asyvars stack over(dersource, ...)
p2 <- ggplot(agg_state_dersource,
             aes(x = dersource, y = landings / 1e6, fill = state)) +
  geom_col() +
  labs(
    x     = "Data source",
    y     = "Millions of pounds",
    fill  = "State",
    title = "BSB landings by data source and state (2010-present)"
  ) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(img_dir, "dersource_landings_by_state.png"),
       plot = p2, width = 9, height = 6, dpi = 150)
message("Saved: dersource_landings_by_state.png")


# =============================================================================
# Chart 3: full time series by dersource
# Stata: preserve; collapse ..., by(year dersource); graph bar ...; (no restore)
# =============================================================================

agg_year_dersource <- dersource_data %>%
  group_by(year, dersource) %>%
  summarise(
    landings = sum(landings, na.rm = TRUE),
    value    = sum(value,    na.rm = TRUE),
    .groups  = "drop"
  )

# Chart 3: stacked by dersource over time
# Stata: graph bar (asis) landings, over(dersource) asyvars stack over(year, ...)
p3 <- ggplot(agg_year_dersource,
             aes(x = factor(year), y = landings / 1e6, fill = dersource)) +
  geom_col() +
  labs(
    x     = "Year",
    y     = "Millions of pounds",
    fill  = "Data source",
    title = "BSB landings by data source over time"
  ) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(img_dir, "dersource_landings_over_time.png"),
       plot = p3, width = 10, height = 6, dpi = 150)
message("Saved: dersource_landings_over_time.png")
