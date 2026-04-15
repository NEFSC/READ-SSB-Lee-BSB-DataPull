# =============================================================================
# Script:  00_exploratory_analysis_wrapper.R
# Purpose: Runs all BSB exploratory analysis scripts in order, producing
#          graphs from Step 1B extraction outputs.
#          Step 2 in the execution sequence — requires Step 1B outputs in
#          data_folder/main/commercial/ and data_folder/external/.
# Inputs:  Set in_string below to match the extraction vintage date
#          (format: YYYY-MM-DD, matching output filenames from extraction scripts).
# Notes:   Ported from stata_code/analysis/00_exploratory_analysis_wrapper.do
#          prices_by_category.R is not included — blocked pending identification
#          of daily_landings_category source script (see CLAUDE_analysis_port_summary.md).
# Author:
# Date:
# =============================================================================

library("here")
here::i_am("R_code/analysis/00_exploratory_analysis_wrapper.R")

# =============================================================================
# *** UPDATE THIS DATE to match your extraction vintage before running ***
# Format: YYYY-MM-DD (e.g., "2025-07-09")
# This must match the date suffix on your extraction output .Rds files.
# NOTE: R extraction scripts use format(Sys.Date()) which gives "YYYY-MM-DD"
# (hyphens), distinct from Stata's "YYYY_MM_DD" (underscores).
# =============================================================================
in_string <- "2025-07-09"

source(here("R_code", "analysis", "bsb_cams_match_coverage.R"))
source(here("R_code", "analysis", "bsb_vessel_explorations.R"))
source(here("R_code", "analysis", "bsb_exploratory.R"))
source(here("R_code", "analysis", "bsb_exploratory_dealers.R"))
source(here("R_code", "analysis", "bsb_seasonal.R"))

message("=== All exploratory analysis scripts complete ===")
