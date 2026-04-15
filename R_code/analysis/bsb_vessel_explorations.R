# =============================================================================
# Script:  bsb_vessel_explorations.R
# Purpose: Stacked bar charts of BSB landings by hullid and by permit,
#          showing the top-25 vessels by all-time total for each state
#          and coastwide. Excludes placeholder/unknown hullids.
# Inputs:  data_folder/main/commercial/landings_all_{in_string}.Rds
# Outputs: images/exploratory/hullid_{state}.png    (one per state)
#          images/exploratory/permit_{state}.png     (one per state)
#          images/exploratory/hullid_coastwide.png
#          images/exploratory/permit_coastwide.png
# Notes:   Ported from stata_code/analysis/bsb_vessel_explorations.do
#          in_string must be set before sourcing (via wrapper or manually).
#          Stata uses tsfill + reshape wide + graph bar for stacked bars;
#          R uses tidyr::complete() + ggplot2::geom_col(position="stack").
#          Top-25 selected by all-time vessel total (matching Stata bysort-tl logic).
# Author:
# Date:
# =============================================================================

library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)

here::i_am("R_code/analysis/bsb_vessel_explorations.R")
source(here("R_code", "project_logistics", "R_paths_libraries.R"))

if (!exists("in_string")) {
  stop("'in_string' not defined. Run via 00_exploratory_analysis_wrapper.R or set in_string manually.")
}

img_dir <- file.path(my_images, "exploratory")
if (!dir.exists(img_dir)) dir.create(img_dir, recursive = TRUE)

# Placeholder hullids to exclude (Stata: multiple drop if inlist(hullid, ...))
bad_hullids <- c(
  "PA9999", "NY0000", "MD9999", "NJ9999", "NC9999", "NH9999", "MS9999",
  "VA9999", "NY9999", "CTD9999", "RI9999",
  "000", "0000", "00000", "000000", "0000000", "00000000",
  "999999", "Unknown", "UNREGISTER", "FROM_SHORE"
)

atlantic_states <- c("CT", "DE", "MA", "MD", "NC", "NJ", "NY", "RI", "VA")


# =============================================================================
# Load and prepare
# =============================================================================

landings_raw <- readRDS(
  file.path(data_main, "commercial", glue("landings_all_{in_string}.Rds"))
)

landings <- landings_raw %>%
  filter(merge_species_codes != 1) %>%
  mutate(dlr_date = as.Date(dlr_date)) %>%
  # Collapse to permit-hullid-state-year and convert to 000s lbs
  group_by(year, state, permit, hullid) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
  mutate(lndlb = lndlb / 1000) %>%
  # Keep Atlantic states; drop vessel size class placeholders and pure-state records
  filter(
    state %in% atlantic_states,
    !permit %in% c("190998", "290998", "390998", "490998"),
    !(hullid %in% c("0000000", "000000") & permit == "000000"),
    hullid != "FROM_SHORE"
  )


# =============================================================================
# Helper: select top-25 vessels by all-time total, fill zeros for missing years
# Mirrors Stata: encode; tsset; tsfill, full; bysort id: egen tl=total(lndlb);
#                bysort year (tl): gen r=_N-_n+1; keep if r<=25
# =============================================================================

top25_by_id <- function(df, id_col) {
  id_sym <- sym(id_col)

  df %>%
    # complete() = tsfill, full: fill all id × year combos with lndlb = 0
    complete(!!id_sym, year, fill = list(lndlb = 0)) %>%
    # all-time total per id (bysort id: egen tl=total(lndlb))
    group_by(!!id_sym) %>%
    mutate(tl = sum(lndlb)) %>%
    ungroup() %>%
    # rank within each year by all-time total, descending (r=1 = largest)
    group_by(year) %>%
    mutate(r = rank(-tl, ties.method = "first")) %>%
    ungroup() %>%
    filter(r <= 25) %>%
    select(-tl, -r)
}


# =============================================================================
# Helper: stacked bar chart of landings by vessel id
# =============================================================================

stacked_bar <- function(df, id_col, title_str) {
  ggplot(df, aes(x = factor(year), y = lndlb, fill = .data[[id_col]])) +
    geom_col() +
    labs(
      x     = "Year",
      y     = "Landings (000s lbs)",
      title = title_str
    ) +
    theme_bw() +
    theme(
      legend.position  = "none",
      axis.text.x      = element_text(angle = 45, hjust = 1)
    )
}


# =============================================================================
# Per-state plots: hullid and permit
# Stata: levelsof state; foreach st { preserve; keep if state=="`st'"; ... }
# =============================================================================

walk(sort(unique(landings$state)), function(st) {

  # --- Hullid stacked bar ---
  hull_data <- landings %>%
    filter(state == st) %>%
    group_by(hullid, year) %>%
    summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
    filter(!hullid %in% bad_hullids) %>%
    top25_by_id("hullid")

  p_hull <- stacked_bar(hull_data, "hullid",
                        glue("{st} landings by hullid (top 25)"))
  ggsave(file.path(img_dir, glue("hullid_{st}.png")),
         plot = p_hull, width = 10, height = 6, dpi = 150)
  message(glue("Saved: hullid_{st}.png"))

  # --- Permit stacked bar ---
  permit_data <- landings %>%
    filter(state == st) %>%
    group_by(permit, year) %>%
    summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
    filter(permit != "000000") %>%   # Stata: drop if inlist(permit,0)
    top25_by_id("permit")

  p_permit <- stacked_bar(permit_data, "permit",
                          glue("{st} landings by permit (top 25)"))
  ggsave(file.path(img_dir, glue("permit_{st}.png")),
         plot = p_permit, width = 10, height = 6, dpi = 150)
  message(glue("Saved: permit_{st}.png"))
})


# =============================================================================
# Coastwide plots
# =============================================================================

# Coastwide hullid
hull_cw <- landings %>%
  group_by(hullid, year) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
  filter(!hullid %in% bad_hullids) %>%
  top25_by_id("hullid")

p_hull_cw <- stacked_bar(hull_cw, "hullid", "Top 25 landings by hullid — coastwide")
ggsave(file.path(img_dir, "hullid_coastwide.png"),
       plot = p_hull_cw, width = 10, height = 6, dpi = 150)
message("Saved: hullid_coastwide.png")

# Coastwide permit
permit_cw <- landings %>%
  group_by(permit, year) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
  filter(permit != "000000") %>%
  top25_by_id("permit")

p_permit_cw <- stacked_bar(permit_cw, "permit", "Top 25 landings by permit — coastwide")
ggsave(file.path(img_dir, "permit_coastwide.png"),
       plot = p_permit_cw, width = 10, height = 6, dpi = 150)
message("Saved: permit_coastwide.png")
