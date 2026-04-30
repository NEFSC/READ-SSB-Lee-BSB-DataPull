# =============================================================================
# Script:  investigate_cams_stockeff.R
# Purpose: Investigate differences between cams and stockeff
# Inputs:  
# File:   input_path  <- here("data_folder", "main", "commercial")
# input_path <- glue("landings_all_{vintage_string}.Rds")
# input_path <- file.path(output_dir, input_path)
# landings_all<-readRDS(file = input_path)
# created by bsb_transactions.R
# =============================================================================

library("ROracle")
library("glue")
library("tidyverse")
library("here")
library("conflicted")
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::summarise)
conflicts_prefer(dplyr::arrange)

here::i_am("R_code/analysis/investigate_cams_stockeff.R")
vintage_string <-"2026-04-30"

# =============================================================================
# Section 1: READ in results of bsb_transactions
# =============================================================================

input_path  <- here("data_folder", "main", "commercial")
input_file <- glue("landings_all_{vintage_string}.Rds")
input_path <- file.path(input_path, input_file)


landings_all<-readRDS(file = input_path)

landings_all_classed <- landings_all %>%
  mutate(
    stock_abbrev = case_when(
      area >= 621 & area<=639 ~ "SOUTH",
      area %in% c(614, 615)   ~ "SOUTH",
      area %in% c(464,465,467,468,510,511,512,513,514,515) ~ "NORTH",
      area %in% c(520,521,522,523,524,525,526,530,533,534,537,538,539,541,542) ~ "NORTH",
      area %in% c(543,551,552,560,561,562,611,612,613,616)~ "NORTH",
      area==0 ~ "UNK",
      .default = "UNK"
    )
  )

  

aggregated_landings<-landings_all_classed %>%

  group_by(year,stock_abbrev) %>%
  summarise(livkg=sum(livlb/2.204))


output_dir  <- here("data_folder", "main", "commercial")
output_file <- glue("aggregated_landings_cams_check{vintage_string}.Rds")
output_path <- file.path(output_dir, output_file)

saveRDS(aggregated_landings, file = output_path)
