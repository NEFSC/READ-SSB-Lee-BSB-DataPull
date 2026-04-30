# =============================================================================
# Script:  bsb_cams_match_coverage.R
# Purpose: Investigate CAMS status variable for BSB. Rebins DLR_ORPHAN_SPECIES
#          to MATCH (combined as "matched") and produces graphs comparing
#          CAMS matched/unmatched landings against VTR hails, coastwide and
#          by state.
# Inputs:  data_folder/main/commercial/landings_all_{in_string}.Rds
#          data_folder/main/commercial/veslog_annual_landings_{in_string}.Rds
#          data_folder/main/commercial/veslog_annual_state_landings_{in_string}.Rds
# Outputs: images/exploratory/cams_match_state.png
#          images/exploratory/cams_match.png
#          images/exploratory/cams_veslog_hails.png
#          images/exploratory/state_cams_veslog_hails.png
#          images/exploratory/cams_veslog_hails_{state}.png  (one per state)
# Notes:   Ported from stata_code/analysis/bsb_cams_match_coverage.do
#          in_string must be set before sourcing (via wrapper or manually).
# =============================================================================


if (!exists("in_string")) {
  stop("'in_string' not defined. Run via 00_exploratory_analysis_wrapper.R or set in_string manually.")
}


atlantic_states <- c("CT", "DE", "MA", "MD", "NC", "NJ", "NY", "RI", "VA")


# =============================================================================
# Load and prepare landings_all
# =============================================================================

landings_raw <- readRDS(
  here("data_folder", "main", "commercial", glue("landings_all_{in_string}.Rds"))
)

landings <- landings_raw %>%
  filter(merge_species_codes != 1) %>%
  mutate(
    dlr_date = as.Date(dlr_date),                      # Oracle POSIXct → Date
    dateq    = paste0(year(dlr_date), "Q", quarter(dlr_date)),
    # s2 = 1 if status is MATCH or DLR_ORPHAN_SPECIES (Stata: rebin as "matched")
    s2 = status %in% c("MATCH", "DLR_ORPHAN_SPECIES")
  )


# =============================================================================
# Section 1: State-level match fractions
# =============================================================================

cams_by_state <- landings %>%
  group_by(year, state, s2) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
  group_by(year, state) %>%
  mutate(t = sum(lndlb), frac = lndlb / t) %>%
  ungroup()

# Save a copy without frac for later merge (tempfile cams_states in Stata)
cams_states <- cams_by_state %>% select(year, state, s2, lndlb)

# Plot: fraction of matched landings by state over time (xtline equivalent)
p_match_state <- cams_by_state %>%
  filter(s2, state %in% atlantic_states, year <= 2023) %>%
  ggplot(aes(x = year, y = frac)) +
  geom_line() +
  facet_wrap(~ state) +
  labs(
    y     = "Fraction of Landings with STATUS == MATCH_OS",
    x     = "Year",
    title = "CAMS match fraction by state"
  ) +
  scale_x_continuous(breaks = c(1995, 2005, 2015, 2025)) +
  theme_bw()

ggsave(file.path(img_dir, "cams_match_state.png"),
       plot = p_match_state, width = 12, height = 8, dpi = 150)
message("Saved: cams_match_state.png")


# =============================================================================
# Section 2: Coastwide match fraction
# =============================================================================

cams_coastwide <- cams_by_state %>%
  group_by(year, s2) %>%
  summarise(lndlb = sum(lndlb, na.rm = TRUE), .groups = "drop") %>%
  group_by(year) %>%
  mutate(t = sum(lndlb), frac = lndlb / t) %>%
  ungroup()

p_match_cw <- cams_coastwide %>%
  filter(s2, year <= 2023) %>%
  ggplot(aes(x = year, y = frac)) +
  geom_line() +
  labs(
    y     = "Fraction of Landings with STATUS == MATCH_OS",
    x     = "Year",
    title = "CAMS match fraction — coastwide"
  ) +
  scale_x_continuous(breaks = c(1995, 2005, 2015, 2025)) +
  theme_bw()

ggsave(file.path(img_dir, "cams_match.png"),
       plot = p_match_cw, width = 8, height = 5, dpi = 150)
message("Saved: cams_match.png")


# =============================================================================
# Section 3: CAMS matched/unmatched landings vs VTR hails — coastwide
# =============================================================================

veslog_annual <- readRDS(
  here("data_folder", "main", "commercial", glue("veslog_annual_landings_{in_string}.Rds"))
)

# Reshape wide: one column for matched, one for unmatched landings
# Stata: reshape wide lndlb, i(year) j(s2); rename lndlb0/1
cams_wide_cw <- cams_coastwide %>%
  mutate(series = if_else(s2, "cams_landings_match", "cams_landings_nomatch")) %>%
  select(year, series, lndlb) %>%
  pivot_wider(names_from = series, values_from = lndlb)

cams_vs_veslog <- cams_wide_cw %>%
  inner_join(veslog_annual %>% select(year, veslog_kept_lbs), by = "year")

# Stata: assert _merge==3
stopifnot(nrow(cams_vs_veslog) == nrow(cams_wide_cw))

# Convert to millions of lbs (Stata: replace var=var/1000000)
cams_vs_veslog_long <- cams_vs_veslog %>%
  filter(year <= 2023) %>%
  mutate(across(c(cams_landings_nomatch, cams_landings_match, veslog_kept_lbs),
                ~ .x / 1e6)) %>%
  pivot_longer(
    cols      = c(cams_landings_nomatch, cams_landings_match, veslog_kept_lbs),
    names_to  = "series",
    values_to = "landings_mlbs"
  ) %>%
  mutate(series = recode(series,
    cams_landings_nomatch = "CAMS No Match",
    cams_landings_match   = "CAMS MATCH_OS",
    veslog_kept_lbs       = "VTR"
  ))

p_hails_cw <- ggplot(cams_vs_veslog_long,
                     aes(x = year, y = landings_mlbs, color = series, linetype = series)) +
  geom_line(linewidth = 0.9) +
  labs(
    y = "M lbs", x = "Year",
    color = NULL, linetype = NULL,
    title = "CAMS landings vs VTR hails — coastwide"
  ) +
  scale_x_continuous(breaks = c(1995, 2005, 2015, 2025),
                     minor_breaks = seq(1995, 2025, 5)) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(img_dir, "cams_veslog_hails.png"),
       plot = p_hails_cw, width = 10, height = 6, dpi = 150)
message("Saved: cams_veslog_hails.png")


# =============================================================================
# Section 4: CAMS matched/unmatched landings vs VTR hails — by state
# =============================================================================

veslog_state <- readRDS(
  here("data_folder", "main", "commercial", glue("veslog_annual_state_landings_{in_string}.Rds"))
)

cams_wide_state <- cams_states %>%
  mutate(series = if_else(s2, "cams_landings_match", "cams_landings_nomatch")) %>%
  select(year, state, series, lndlb) %>%
  pivot_wider(names_from = series, values_from = lndlb)

# Stata: merge 1:1 state year using veslog_annual_state_landings, keep(1 3)
# assert _merge==3 follows; using left_join then checking no unmatched masters.
state_data <- cams_wide_state %>%
  left_join(veslog_state %>% select(year, state, veslog_kept_lbs),
            by = c("year", "state")) %>%
  filter(state %in% atlantic_states)

stopifnot(sum(is.na(state_data$veslog_kept_lbs)) == 0)  # assert _merge==3

state_data_long <- state_data %>%
  filter(year <= 2023) %>%
  mutate(across(c(cams_landings_nomatch, cams_landings_match, veslog_kept_lbs),
                ~ .x / 1e6)) %>%
  pivot_longer(
    cols      = c(cams_landings_nomatch, cams_landings_match, veslog_kept_lbs),
    names_to  = "series",
    values_to = "landings_mlbs"
  ) %>%
  mutate(series = recode(series,
    cams_landings_nomatch = "CAMS No Match",
    cams_landings_match   = "CAMS MATCH_OS",
    veslog_kept_lbs       = "VTR"
  ))

p_hails_state <- ggplot(state_data_long,
                        aes(x = year, y = landings_mlbs, color = series, linetype = series)) +
  geom_line(linewidth = 0.9) +
  facet_wrap(~ state) +
  labs(
    y = "M lbs", x = "Year",
    color = NULL, linetype = NULL,
    title = "CAMS landings vs VTR hails by state"
  ) +
  scale_x_continuous(breaks = c(1995, 2005, 2015, 2025),
                     minor_breaks = seq(1995, 2025, 5),
                     guide = guide_axis(check.overlap = TRUE)) +
  theme_bw(base_size = 9) +
  theme(legend.position = "bottom")

ggsave(file.path(img_dir, "state_cams_veslog_hails.png"),
       plot = p_hails_state, width = 12, height = 9, dpi = 150)
message("Saved: state_cams_veslog_hails.png")


# =============================================================================
# Section 5: Per-state individual plots
# Stata: levelsof state, local(mystates); foreach l of local mystates { tsline ... }
# =============================================================================

walk(sort(unique(state_data_long$state)), function(st) {
  p <- state_data_long %>%
    filter(state == st) %>%
    ggplot(aes(x = year, y = landings_mlbs, color = series, linetype = series)) +
    geom_line(linewidth = 0.9) +
    labs(
      y = "M lbs", x = "Year",
      color = NULL, linetype = NULL,
      title = glue("CAMS vs VTR — {st}")
    ) +
    scale_x_continuous(breaks = c(1995, 2005, 2015, 2025),
                       minor_breaks = seq(1995, 2025, 5)) +
    theme_bw() +
    theme(legend.position = "bottom")

  fname <- file.path(img_dir, glue("cams_veslog_hails_{st}.png"))
  ggsave(fname, plot = p, width = 8, height = 5, dpi = 150)
  message(glue("Saved: cams_veslog_hails_{st}.png"))
})
