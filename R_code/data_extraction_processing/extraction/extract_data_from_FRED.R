# =============================================================================
# Script:  extract_data_from_FRED.R
# Purpose: Pull CPI (CPIAUCSL) from the St. Louis Fed FRED API and compute
#          annual and quarterly price deflators normalised to a base period.
# Inputs:  FRED API (internet access + API key required)
# Outputs: data_folder/external/deflatorsY_{vintage_string}.Rds
#            Annual CPI deflator (base year 2023 = 1.0).
#          data_folder/external/deflatorsQ_{vintage_string}.Rds
#            Quarterly CPI deflator (base period 2023Q1 = 1.0).
# Notes:   Ported from stata_code/data_extraction_processing/extraction/
#          extract_data_from_FRED.do
#          FRED API key must be set via fredr_set_key() or the FRED_API_KEY
#          environment variable (recommended: store in .Rprofile or keyring).
#          To deflate a nominal value: divide by fCPIAUCSL_YYYY[Q].
#          To inflate a real value:    multiply by fCPIAUCSL_YYYY[Q].
# Author:
# Date:
# =============================================================================

library("fredr")

# Set FRED API key.  Store key in environment or keyring — never hardcode.
# Stata equivalent: set fredkey <key>
fredr_set_key(Sys.getenv("FRED_API_KEY"))

# Base periods (update if a different reference period is needed)
base_yr  <- 2023          # annual base year
base_qtr <- "2023 Q1"     # quarterly base period (lubridate::yq() format)


# =============================================================================
# Section 1: Annual CPI deflator
# =============================================================================

cpi_annual_raw <- fredr(
  series_id          = "CPIAUCSL",
  observation_start  = as.Date("1996-01-01"),
  frequency          = "a",           # annual
  aggregation_method = "avg"          # average of monthly values
)

cpi_annual <- cpi_annual_raw %>%
  select(date, cpiaucsl = value) %>%
  mutate(year = year(date)) %>%
  # Normalise: fCPIAUCSL_{base_yr} = CPIAUCSL / CPIAUCSL[year == base_yr]
  # Stata: gen baseCPIAUCSL = CPIAUCSL if year == basey; sort baseCPIAUCSL; ...
  mutate(
    base_val          = cpiaucsl[year == base_yr],
    fCPIAUCSL_2023    = cpiaucsl / base_val
  ) %>%
  select(year, cpiaucsl, fCPIAUCSL_2023) %>%
  arrange(year)

# fCPIAUCSL_2023: divide a nominal price by this to get real 2023 dollars;
#                 multiply a real 2023 price by this to get nominal dollars.

annual_path <- here("data_folder", "external",
                    glue("deflatorsY_{vintage_string}.Rds"))
if (!dir.exists(dirname(annual_path))) dir.create(dirname(annual_path), recursive = TRUE)
saveRDS(cpi_annual, file = annual_path)
message(glue("Saved: {annual_path}"))


# =============================================================================
# Section 2: Quarterly CPI deflator
# =============================================================================

cpi_qtr_raw <- fredr(
  series_id          = "CPIAUCSL",
  observation_start  = as.Date("1996-01-01"),
  frequency          = "q",           # quarterly
  aggregation_method = "avg"
)

# Identify the base quarter value for normalisation.
# Stata: local baseq = quarterly("2023Q1","Yq"); gen baseCPIAUCSL = CPIAUCSL if dateq == baseq
base_qtr_date <- yq(base_qtr)   # lubridate::yq converts "2023 Q1" → Date of first day

cpi_quarterly <- cpi_qtr_raw %>%
  select(date, cpiaucsl = value) %>%
  mutate(
    base_val           = cpiaucsl[date == base_qtr_date],
    fCPIAUCSL_2023Q1   = cpiaucsl / base_val,
    # Retain a readable quarter label alongside the date
    quarter            = paste0(year(date), "Q", quarter(date))
  ) %>%
  select(date, quarter, cpiaucsl, fCPIAUCSL_2023Q1) %>%
  arrange(date)

# fCPIAUCSL_2023Q1: divide nominal price by this to get real 2023Q1 dollars.

qtr_path <- here("data_folder", "external",
                 glue("deflatorsQ_{vintage_string}.Rds"))
saveRDS(cpi_quarterly, file = qtr_path)
message(glue("Saved: {qtr_path}"))
