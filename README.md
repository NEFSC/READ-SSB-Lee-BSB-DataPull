# Black Sea Bass

This repository holds data extraction, processing, and exploration code for Min-Yang's black sea bass projects.  

It includes a datapull from CAMS and other sources, data exploration, and 
moderate amounts of data processing that is (hopefully) general to all projects. 

Code to extract data from NEFSC Oracle databases will need to be run by a user with access.  This code can be found in 
```
├── READ-SSB-Lee-BSB-DataPull/  
│   ├── R_code/            
│ 	  ├── data_extraction_processing
│ 	  	├── extraction
│   ├── stata_code/            
│ 	  ├── data_extraction_processing
│ 	  	├── extraction
```

All results of the data extraction code will be put into

```
├── READ-SSB-Lee-BSB-DataPull/  
│   ├── data_folder/            
│ 	  ├── raw
```
This code supports

1. "Economic-informed stock assessments": Because the 
size of an individual fish determines the price of fish, we can invert this 
relationship to help fill in gaps when we do not sample the lengths of those fish.
There are 5 prevailing BSB market categories: Jumbo, Large, Medium, Small, and
Unclassified.  From 2020 to 2023, 5 to 10% of commercial landings were in the 
“Unclassified” market category; but no fish in this category were measured. We 
train a Random Forest model to transactions data from 2015-2024 and use the results
to predict the class of the Unclassified market category.

2. "Catch shares, Environmental variation, and Port choice": There are different
regulations in each state.  Three states have a catch share program. The others 
do not; these states have a wide range of possession limits. Gear restrictions, 
mostly mesh size (trawl) or vent size (pot), are similar, but also vary by state.
How does the intersection of these regulations and changes in biomass due to 
environmental variation affect where people fish, how productive they are, and 
where they land their catch?  This may be 2 or 3 projects.

3. Other Projects
 
#  Folder structure

Folder structure is mostly borrowed from the world bank's EDB. https://dimewiki.worldbank.org/wiki/Stata_Coding_Practices
Try to use forward slashes (that is C:/path/to/your/folder) instead of backslashes for unix/mac compatability. 

Your life will be easier if you organize things into a BSB_mega_folder because there are a few linked projects.
```
BSB_mega_folder/
├── READ-SSB-Lee-BSB-DataPull/  #Data pull, explore, background. 
│   ├── data_folder/              # Shared data
│ 	  ├── raw/	   
│ 	  ├── external/
│ 	  └── internal/
│ 	  ├── intermediate/
│ 	  └── main/
│   ├── R_code/
│   ├── stata_code/
│   └──more stuff/
├── READ-SSB-Lee-BlackSeaBass/  #Prices in stock assessment Repository
│   ├── READ-SSB-Lee-BlackSeaBass.Rproj
│   ├── data_folder
│   	├── data_raw/              # Raw data (minimal)
│   	└── data_main/              # Final data specific to this project.
│   ├── results/
│   ├── R_code/
│   ├── stata_code/
│   └── README.md
├── PortChoice/                  #Port Choice  Repository
│   ├── PortChoice.Rproj  
│   ├── data_folder
│   	├── data_raw/              # Raw data (minimal)
│   	└── data_main/               # Final data specific to this project.
│   ├── results/
│   ├── R_code/
│   ├── stata_code/
│   └── README.md

```


## Running stata code in this project.  

Add this line of code to the ``profile.do`` that is executed on Stata's startup
```
global my_project_name "full/path/to/stata_code/project_logisitics/folder_setup_globals.do"

```
A stata do file containing folder names get stored as a macro in stata's startup profile.do.  This lets me start working on any of my projects by opening stata and typing: 
```
do $my_project_name
```
Rstudio users using projects don't have to do this step.


# Domain Reference

1. Species codes use itis, Black Sea Bass is 167687.
2. Gear codes (negear) are binned into gear groups.

## Species Codes (ITIS TSN)

| ITIS TSN | Common Name | Used In |
|----------|-------------|---------|
| 167687 | Black Sea Bass (*Centropristis striata*) | 12+ files (primary filter) |
| 172735 | Summer Flounder | `sfbsb_daily.do` |

> NESPP3 code for BSB: 335. [TO DOCUMENT: full NESPP3 list if needed]

## Gear Codes (negear) — Category Mapping

The `negear` field contains NEFSC gear codes. Analysis scripts bin these into
five final categories. Source: `stata_code/analysis/bsb_exploratory.do` lines 53–92.

| Category | negear values |
|----------|--------------|
| LineHand | 10, 20, 21, 30, 34, 40, 60, 62, 65, 66, 90, 220–230, 250, 251, 330, 340, 380, 410, 414, 420 |
| Trawl | 50–59, 71, 150, 160, 170, 350, 351, 353, 370, 450 |
| Gillnet | 100–117, 500, 520 |
| PotTrap | 80, 140, 142, 180–212, 240, 260, 270, 300–301, 320, 322 (includes weirs and pounds) |
| Misc | Dredge (381–383, 132, 400), Seine (70, 71, 120–124, 160, 360), Unknown (999) |

> Dredge, Seine, and Unknown are first assigned their own categories, then
> rebinned into `Misc`. The final analysis uses five categories: LineHand,
> Trawl, Gillnet, PotTrap, Misc.

## Market Category Codes

BSB is sold in five size-based market categories. Raw dealer records contain
additional codes that are rebinned during processing.
Source: `stata_code/analysis/bsb_exploratory.do` lines 78–97.

| Final Code | Final Description | Raw Codes Rebinned In |
|-----------|------------------|-----------------------|
| JB | Jumbo | JB, XG (Extra Large) |
| LG | Large | LG |
| MD | Medium | MD, Medium Or Select |
| SQ | Small | SQ, PW (Pee Wee), ES (Extra Small) |
| UN | Unclassified | UN, MX (Mixed or Unsized) |

>The stock assessment uses "SMALL.COMB" for Small Combined.

> The Unclassified category (5–10% of landings 2020–2023) is the focus
> of the stock assessment price-prediction work.

## Permit Type Codes

Used in `commercial_BSB.do` and `bsb_vessel_explorations.do` to distinguish
state-permitted from federally-permitted vessels.

| Permit Value | Type | Notes |
|-------------|------|-------|
| 000000 | State (no federal permit) | CAMSID constructed from permit+hullid+dealer fields; excluded from apportionment |
| 190998 | Vessel size class A| Dropped from vessel-level analysis |
| 290998 | Vessel size class B| Dropped from vessel-level analysis |
| 390998 | vessel size class C| Dropped from vessel-level analysis |
| 490998 | vessel size class D| Dropped from vessel-level analysis |
| All others | Federal | 6-digit federal permit number |

>The 998 permits correspond to vessels with an unknown/no permit, but in a particular size bin.


## Dealer/Trip Match Status Codes

The `status` field in CAMS records describes how dealer (CFDERS) and vessel
trip (VTR) records were matched.
Source: `stata_code/analysis/bsb_exploratory_dealers.do` lines 155–171.

| Status Code | Meaning |
|------------|---------|
| MATCH | Records fully match at the CAMSID–ITIS_GROUP1 level |
| DLR_ORPHAN_SPECIES | Matching CAMSID but ITIS_GROUP1 in CFDERS does not appear on the VTR |
| DLR_ORPHAN_TRIP | Dealer trip with no matching VTR trip |
| VTR_ORPHAN_SPECIES | Matching CAMSID but ITIS_GROUP1 on VTR does not appear in CFDERS |
| VTR_ORPHAN_TRIP | VTR trip with no matching trip in CFDERS |
| VTR_NOT_SOLD | VTR record for bait/home consumption; not sold to dealer; not in CFDERS |
| PZERO | PERMIT = '000000'; excluded from apportionment and imputation |



# Data, Oracle, passwords and other confidential information

In order to run this code, you need to be able to ``select`` on various NEFSC oracle tables.  For stata, you will need to assemble an oracle connection string into the global ``myNEFSC_USERS_conn.``  The best way to do that is to assemble that in your ``.profile.do`` that is run on startup. 

Basically, you will want to store them in a place that does not get uploaded to github. 

For stata users, there is a description [here](/documentation/project_logistics.md). 

For R users, try setting and storing information in a keyring using the package ``keyring::key_set()``   You can read them in using ``keyring::key_get()`` 
If you can encrypt your [.Rprofile](/R_code/project_logistics/.Rprofile_sample), that another solution for passwords, API keys, and tokens.  

# NOAA Requirements
This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.”


1. who worked on this project:  Min-Yang Lee
1. when this project was created: Summer 2024 
1. what the project does: Black Sea bass related projects
1. why the project is useful:  Black Sea bass is awesome
1. how users can get started with the project: Download and follow the readme
1. where users can get help with your project:  email at Min-Yang.Lee@noaa.gov or open an issue
1. who maintains and contributes to the project. Min-Yang

# License file
See here for the [license file](License.txt)
