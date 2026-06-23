# ======================================================================
# GRR predictive analysis: MASTER all-in-one diagnostic + corrected revision script
# ======================================================================
#
# What this script does
# ---------------------
# This is the single master script for the predictive-analysis part of the
# paper.
#
# How to use
# ----------
# Put this file in the same folder as your data, helper scripts, and RData
# simulation outputs, then run:
#
#   source("GRR_predictive_analysis_MASTER_targeted_positive_global_risks_AUTO_INSTALL_251208.R")
#
# Efficiency note
# ---------------
# The 1,500 Monte Carlo simulations are already run and saved as RData files. 
# This script loads those simulations instead of rerunning them. If the observed
# regional/global regression RData files are missing, the script recomputes the
# observed regressions from the raw CSVs using sim_functions.r. 
#
# Expected files in the same folder
# ---------------------------------
# Required raw data/helper files:
#   - Risks 251014.csv
#   - Shock counts.csv
#   - r5regions.csv
#   - sim_functions.r
#   - run_lag_worker.r              # optional
#
# Required simulation RData files, using either of these regional sets:
#   Set A:
#     - expanding_sim_001_600_200_2025-11-07.RData
#     - expanding_sim_601_1500_900_2025-11-08.RData
#   or Set B:
#     - expanding_sim_1_400_400_2025-11-07.RData
#     - expanding_sim_401_600_200_2025-11-07.RData
#     - expanding_sim_601_1500_900_2025-11-08.RData
#
# Required global simulation files:
#   - glob_expanding_sim_1_1000_1000_2025-11-09.RData
#   - glob_expanding_sim_1001_1500_500_2025-11-10.RData
#
# Optional observed-regression RData files:
#   - expanding_res_2025-11-06.RData       # regional; recomputed if missing
#   - glob_expanding_res_2025-11-08.RData  # global; recomputed if missing
#
# Outputs are written to revision_outputs_predictive_analysis/.
# This corrected revision saves the manuscript/SI figures, lag-level reproducibility tables,
# 95% two-sided Monte Carlo envelopes, and coverage-aware edition-level diagnostics.
# Section 13/13B diagnostics use coverage-aware partial windows at data boundaries:
# years outside category-specific shock coverage are not counted as zeros, but the
# available part of a requested window is still used when at least one coverage
# year is present.
# ======================================================================

# ----------------------------------------------------------------------
# 0. User settings
# ----------------------------------------------------------------------

get_script_dir <- function() {
  cmd <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  hit <- grep(paste0("^", file_arg), cmd, value = TRUE)
  if (length(hit) > 0) {
    return(dirname(normalizePath(sub(paste0("^", file_arg), "", hit[1]))))
  }
  frame_files <- vapply(sys.frames(), function(x) {
    if (!is.null(x$ofile)) x$ofile else NA_character_
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  if (length(frame_files) > 0) {
    return(dirname(normalizePath(frame_files[length(frame_files)])))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    ctx <- tryCatch(rstudioapi::getActiveDocumentContext(), error = function(e) NULL)
    if (!is.null(ctx) && nzchar(ctx$path)) {
      return(dirname(normalizePath(ctx$path)))
    }
  }
  getwd()
}

# By default, use the folder where this script is located. You can override
# manually by replacing the next line with your own path, for example:
# wd <- "C:/Users/psoga/Cloud-Drive/ESCAPE/WEF"
wd <- get_script_dir()
setwd(wd)

output_dir <- file.path(wd, "revision_outputs_predictive_analysis")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

DELETE_OLD_FIGURES_IN_OUTPUT_DIR <- TRUE
if (isTRUE(DELETE_OLD_FIGURES_IN_OUTPUT_DIR)) {
  old_figures <- list.files(
    output_dir,
    pattern = "^Figure_.*\\.(pdf|png)$",
    full.names = TRUE
  )
  if (length(old_figures) > 0) unlink(old_figures)
}

# Input files.
risks_file   <- "Risks 251014.csv"
shocks_file  <- "Shock counts.csv"
regions_file <- "r5regions.csv"
summary_file <- "Predictive and anticipatory capacity and best.csv"

# Original helper scripts.
sim_functions_file <- "sim_functions.r"
lag_worker_file    <- "run_lag_worker.r"

# Simulation files. The script uses the first complete regional set it finds.
regional_sim_file_sets <- list(
  c(
    "expanding_sim_001_600_200_2025-11-07.RData",
    "expanding_sim_601_1500_900_2025-11-08.RData"
  ),
  c(
    "expanding_sim_1_400_400_2025-11-07.RData",
    "expanding_sim_401_600_200_2025-11-07.RData",
    "expanding_sim_601_1500_900_2025-11-08.RData"
  )
)

global_sim_file_sets <- list(
  c(
    "glob_expanding_sim_1_1000_1000_2025-11-09.RData",
    "glob_expanding_sim_1001_1500_500_2025-11-10.RData"
  )
)

# Observed regressions. These are loaded if present; otherwise recomputed.
regional_regression_files <- c("expanding_res_2025-11-06.RData")
global_regression_files   <- c("glob_expanding_res_2025-11-08.RData")

# Leave FALSE for the normal manuscript run. Set TRUE only if you deliberately
# want to ignore existing observed-regression RData files and recompute observed
# coefficients from the raw CSVs with the current settings. If this is changed
# after simulations were generated, regenerate/reload matching simulation RData as well.
FORCE_RECOMPUTE_OBSERVED_REGRESSIONS <- FALSE

# Analysis settings matching the original expanding-window analysis.
# The predictive analysis uses the comparable GRPS-derived risk-score period.
# Later GRRs are used in the thematic/linguistic analyses but excluded here
# because the published GRPS scoring changed after 2021.
PREDICTIVE_GRR_YEAR_MIN <- 2006L
PREDICTIVE_GRR_YEAR_MAX <- 2021L

# IMPORTANT: include0 and INCLUDE_RISK_YEAR_IN_WINDOWS are intentionally TRUE.
# The predictive windows are therefore inclusive of the GRR assessment year:
# prospective windows cover y to y + h, and retrospective windows cover
# y - h to y. Interpret coefficients as near-term alignment rather than
# as strictly out-of-sample forecasts beginning after the GRR year.
max_lag  <- 5
include0 <- TRUE
INCLUDE_RISK_YEAR_IN_WINDOWS <- TRUE

# Section 13/13B diagnostics should not treat structurally unavailable years as
# observed zero-shock years. By default, they allow partial windows near
# category-specific coverage boundaries. For example, if diseases coverage ends
# in 2022, a five-year prospective window for the 2018 GRR is evaluated over
# 2018-2022 rather than being dropped because 2023 is unavailable. The number
# of years actually used is exported in the diagnostic CSVs.
SECTION13_ALLOW_PARTIAL_WINDOWS <- TRUE
SECTION13_MIN_WINDOW_OBSERVED_YEARS <- 1L

# Centered smoothing for the annual-component diagnostic. Requiring the central
# annual component avoids drawing a smoothed line into years where no annual
# component could be computed. A minimum of one non-missing value lets the line
# follow the available diagnostic component at coverage boundaries, consistent
# with the partial-window choice above.
SECTION13_ROLLING_MEAN_REQUIRE_CENTER <- TRUE
SECTION13_ROLLING_MEAN_MIN_NON_MISSING <- 1L

min_n    <- 5

# Simulation envelope used for lag-level point classification in Figure 1/S6.
# Use 0.025/0.975 for a two-sided 95% Monte Carlo envelope, matching P < 0.05
# language in captions and legends.
SIM_ENVELOPE_LOWER <- 0.025
SIM_ENVELOPE_UPPER <- 0.975

# Number of coefficient draws for parametric uncertainty intervals.
# Use 10000 for final results; reduce for quick testing.
B_PARAMETRIC_CI <- 10000

# Bootstrap draws for paired mean-difference CIs if pairwise contrasts are enabled.
# Pairwise contrasts are not used for the main targeted inference because the
# targeted test has only four risk-category blocks.
B_INCOME_DIFF_CI <- 10000

# Package installation behavior.
# TRUE: install any missing CRAN packages automatically.
# FALSE: stop and list missing packages.
AUTO_INSTALL_MISSING_PACKAGES <- TRUE
CRAN_REPO <- "https://cloud.r-project.org"

# Targeted revision analysis. These four categories are the categories for which
# the current global analysis has positive predictive capacity. The script writes
# a check table to confirm this against the recomputed summary.
TARGET_RISKS_POSITIVE_GLOBAL <- c("Climate", "Diseases", "GeoConflict", "Terror")
MAKE_ALL_RISK_SENSITIVITY_TABLES <- TRUE

set.seed(20251208)

risk_levels <- c(
  "Geophysical", "Climate", "Diseases", "Food",
  "Economic", "GeoConflict", "Terror", "Tech"
)

region_levels <- c("Global", "HIC", "UMC", "LMC", "LIC")
income_levels <- c("HIC", "UMC", "LMC", "LIC")

map_risk <- c(
  "CLIMATIC"      = "Climate",
  "GEOPHYSICAL"   = "Geophysical",
  "ECOLOGICAL"    = "Food",
  "TECHNOLOGICAL" = "Tech",
  "CONFLICTS"     = "GeoConflict",
  "ECONOMIC"      = "Economic",
  "DISEASES"      = "Diseases",
  "TERRORISM"     = "Terror"
)

# Okabe-Ito style palette.
risk_pal <- c(
  "Geophysical" = "#999999",
  "Climate"     = "#E69F00",
  "Diseases"    = "#56B4E9",
  "Food"        = "#009E73",
  "Economic"    = "#D55E00",
  "GeoConflict" = "#0072B2",
  "Terror"      = "#CC79A7",
  "Tech"        = "#000000"
)

sig_pal <- c(
  "BOTH" = "#000000",
  "SIM"  = "#009E73",
  "REG"  = "#0072B2",
  "NONE" = "#B3B3B3"
)

region_shapes <- c(
  "Global" = 18,
  "HIC"    = 24,
  "UMC"    = 22,
  "LMC"    = 3,
  "LIC"    = 4
)

metric_pal <- c(
  "Predictive alignment" = "#0072B2",
  "Predictive capacity"  = "#0072B2",
  "Anticipatory skill"   = "#D55E00"
)

metric_shapes <- c(
  "Predictive alignment" = 17,
  "Predictive capacity"  = 17,
  "Anticipatory skill"   = 16
)

required_packages <- c(
  "dplyr", "tidyr", "purrr", "broom", "ggplot2", "forcats",
  "countrycode", "wbstats", "grid", "tibble", "scales", "stringr", "zoo"
)

# ----------------------------------------------------------------------
# 1. Packages
# ----------------------------------------------------------------------

# required_packages is defined in the user-settings section above.

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0 && isTRUE(AUTO_INSTALL_MISSING_PACKAGES)) {
  message(
    "Installing missing CRAN package(s): ",
    paste(missing_packages, collapse = ", ")
  )
  install.packages(missing_packages, repos = CRAN_REPO)
}

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "These R packages are still missing after the install attempt: ",
    paste(missing_packages, collapse = ", "),
    "\n\nInstall them manually with:\n",
    "install.packages(c(\"", paste(missing_packages, collapse = "\", \""), "\"), repos = \"", CRAN_REPO, "\")"
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(broom)
  library(ggplot2)
  library(forcats)
  library(countrycode)
  library(wbstats)
  library(grid)
  library(tibble)
  library(scales)
  library(stringr)
})

# ----------------------------------------------------------------------
# 2. General helper functions
# ----------------------------------------------------------------------

require_files <- function(files, purpose) {
  missing <- files[!file.exists(files)]
  if (length(missing) > 0) {
    stop(
      "Missing file(s) needed for ", purpose, ":\n  ",
      paste(missing, collapse = "\n  "),
      "\n\nPut these files in the working directory or update the file names at the top of the script."
    )
  }
  invisible(TRUE)
}

load_rdata_object <- function(file, object_name) {
  env <- new.env(parent = emptyenv())
  loaded <- load(file, envir = env)
  if (!(object_name %in% loaded)) {
    stop(
      "File ", file, " does not contain object '", object_name,
      "'. It contains: ", paste(loaded, collapse = ", ")
    )
  }
  get(object_name, envir = env)
}

source_if_present <- function(file) {
  if (file.exists(file)) {
    source(file)
    message("Sourced: ", file)
  } else {
    warning("Could not find ", file, ". A fallback shock-aggregation function will be used if needed.")
  }
}

save_plot <- function(plot, filename, width, height, dpi = 600) {
  pdf_path <- file.path(output_dir, paste0(filename, ".pdf"))
  png_path <- file.path(output_dir, paste0(filename, ".png"))
  pdf_device <- if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else grDevices::pdf
  ggplot2::ggsave(pdf_path, plot, width = width, height = height, units = "in", device = pdf_device, bg = "white")
  ggplot2::ggsave(png_path, plot, width = width, height = height, units = "in", dpi = dpi, bg = "white")
  message("Saved: ", pdf_path)
  message("Saved: ", png_path)
}

pick_first <- function(nms, candidates) {
  hit <- intersect(candidates, nms)
  if (length(hit) == 0) return(NA_character_)
  hit[1]
}

rename_if_present <- function(df, old, new) {
  if (old %in% names(df) && !(new %in% names(df))) {
    names(df)[match(old, names(df))] <- new
  }
  df
}

format_p <- function(p) {
  ifelse(
    is.na(p),
    "P = NA",
    ifelse(p < 0.001, "P < 0.001", paste0("P = ", sprintf("%.3f", p)))
  )
}

format_p_plain <- function(p) {
  ifelse(
    is.na(p),
    "NA",
    ifelse(p < 0.001, "<0.001", sprintf("%.3f", p))
  )
}

risk_label <- function(x) {
  dplyr::recode(
    as.character(x),
    "Geophysical" = "Geophysical",
    "Climate" = "Climate",
    "Diseases" = "Diseases",
    "Food" = "Food",
    "Economic" = "Economic",
    "GeoConflict" = "Conflicts",
    "Terror" = "Terrorism",
    "Tech" = "Technology",
    .default = as.character(x)
  )
}

pad_limits <- function(x, pad = 0.08, include_zero = TRUE) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(c(NA_real_, NA_real_))
  rng <- range(x, na.rm = TRUE)
  if (include_zero) rng <- range(c(rng, 0), na.rm = TRUE)
  span <- diff(rng)
  if (!is.finite(span) || span == 0) span <- max(1, max(abs(rng), na.rm = TRUE))
  c(rng[1] - pad * span, rng[2] + pad * span)
}

boot_mean_ci <- function(x, B = 10000, probs = c(0.025, 0.975)) {
  x <- x[is.finite(x)]
  if (length(x) < 2) return(c(lwr = NA_real_, upr = NA_real_))
  b <- replicate(B, mean(sample(x, size = length(x), replace = TRUE), na.rm = TRUE))
  q <- quantile(b, probs = probs, na.rm = TRUE, names = FALSE)
  c(lwr = q[1], upr = q[2])
}

wilcox_signed_rank <- function(d) {
  d <- d[is.finite(d)]
  d_nz <- d[d != 0]
  if (length(d) < 2) {
    return(list(statistic = NA_real_, p.value = NA_real_, exact_used = NA))
  }
  if (length(d_nz) == 0) {
    return(list(statistic = 0, p.value = 1, exact_used = TRUE))
  }
  
  exact_try <- tryCatch(
    suppressWarnings(wilcox.test(d_nz, mu = 0, exact = TRUE, correct = FALSE)),
    error = function(e) NULL
  )
  
  if (!is.null(exact_try)) {
    return(list(
      statistic = unname(exact_try$statistic),
      p.value = exact_try$p.value,
      exact_used = TRUE
    ))
  }
  
  asym_try <- tryCatch(
    suppressWarnings(wilcox.test(d_nz, mu = 0, exact = FALSE, correct = FALSE)),
    error = function(e) NULL
  )
  
  if (is.null(asym_try)) {
    return(list(statistic = NA_real_, p.value = NA_real_, exact_used = FALSE))
  }
  
  list(
    statistic = unname(asym_try$statistic),
    p.value = asym_try$p.value,
    exact_used = FALSE
  )
}

standardize_summary_names <- function(x) {
  # Handles both the original column names produced in the R script and the
  # display-oriented names in the CSV you attached.
  x <- rename_if_present(x, "Time.horizon", "lag_max")
  x <- rename_if_present(x, "Time horizon", "lag_max")
  x <- rename_if_present(x, "Predictive.cap", "max_future")
  x <- rename_if_present(x, "Predictive cap", "max_future")
  x <- rename_if_present(x, "Past.corresponding", "corr_past")
  x <- rename_if_present(x, "Past corresponding", "corr_past")
  x <- rename_if_present(x, "Anticipatory.cap", "diff_future_corrpast")
  x <- rename_if_present(x, "Anticipatory cap", "diff_future_corrpast")
  x
}



filter_risk_score <- function(df) {
  if ("term" %in% names(df)) {
    df %>% filter(term == "Risk_Score")
  } else {
    df
  }
}

first_complete_file_set <- function(file_sets, label) {
  for (fs in file_sets) {
    if (all(file.exists(fs))) return(fs)
  }
  all_names <- unique(unlist(file_sets))
  missing <- all_names[!file.exists(all_names)]
  stop(
    "Could not find a complete set of ", label, ". Missing candidates include:\n  ",
    paste(missing, collapse = "\n  "),
    "\n\nPut the RData files in the same folder as this script, or update the file names in Section 0."
  )
}

find_existing_file <- function(files) {
  hit <- files[file.exists(files)]
  if (length(hit) > 0) hit[1] else NA_character_
}

load_rdata_flexible <- function(file, preferred_object = NULL) {
  env <- new.env(parent = emptyenv())
  loaded <- load(file, envir = env)
  
  if (!is.null(preferred_object) && preferred_object %in% loaded) {
    out <- get(preferred_object, envir = env)
    message("Loaded ", preferred_object, " from ", file)
    return(out)
  }
  
  df_candidates <- loaded[vapply(loaded, function(nm) {
    is.data.frame(get(nm, envir = env))
  }, logical(1))]
  
  if (length(df_candidates) == 1) {
    out <- get(df_candidates[1], envir = env)
    message("Loaded ", df_candidates[1], " from ", file)
    return(out)
  }
  
  if (length(loaded) == 1) {
    out <- get(loaded[1], envir = env)
    message("Loaded ", loaded[1], " from ", file)
    return(out)
  }
  
  stop(
    "Could not choose which object to load from ", file,
    ". Objects found: ", paste(loaded, collapse = ", "),
    ". Set preferred_object explicitly or keep only one data-frame object in the file."
  )
}

load_and_bind_rdata <- function(files, preferred_object) {
  bind_rows(lapply(files, load_rdata_flexible, preferred_object = preferred_object))
}

require_functions <- function(function_names, source_file) {
  missing <- function_names[!vapply(function_names, exists, logical(1), mode = "function")]
  if (length(missing) > 0) {
    stop(
      "After sourcing ", source_file, ", these required functions were still missing:\n  ",
      paste(missing, collapse = "\n  "),
      "\n\nCheck that sim_functions.r is in the same folder and is the current version."
    )
  }
  invisible(TRUE)
}


# ----------------------------------------------------------------------
# 3. Source original helper functions and load/clean raw data
# ----------------------------------------------------------------------

require_files(c(risks_file, shocks_file, regions_file, sim_functions_file), purpose = "raw data and helper functions")
source(sim_functions_file)
message("Sourced: ", sim_functions_file)
if (file.exists(lag_worker_file)) source_if_present(lag_worker_file)

require_functions(
  c(
    "smooth_nat_shocks", "make_shocks_reg", "make_shocks_global",
    "run_reg_expand_reg", "run_reg_expand_glob"
  ),
  sim_functions_file
)

risks <- read.csv(risks_file, stringsAsFactors = FALSE, check.names = FALSE)
sh_nat <- read.csv(shocks_file, stringsAsFactors = FALSE, check.names = FALSE)
reg_key <- read.csv(regions_file, col.names = c("Region", "ISO3"), stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")

# Accept either original names with spaces or syntactic names with dots.
sh_nat <- rename_if_present(sh_nat, "Country name", "Country.name")
sh_nat <- rename_if_present(sh_nat, "Shock category", "Shock.category")
sh_nat <- rename_if_present(sh_nat, "Shock type", "Shock.type")

if (!("Year" %in% names(risks))) stop("The risks file must contain a Year column.")
risks$Year <- as.integer(risks$Year)
risk_years_before_filter <- sort(unique(risks$Year))
risks <- risks %>%
  filter(
    Year >= PREDICTIVE_GRR_YEAR_MIN,
    Year <= PREDICTIVE_GRR_YEAR_MAX
  )
if (nrow(risks) == 0) {
  stop("No risk-score rows remain after applying PREDICTIVE_GRR_YEAR_MIN/MAX.")
}
message(
  "Predictive analysis restricted to comparable GRR years ",
  min(risks$Year, na.rm = TRUE), "-", max(risks$Year, na.rm = TRUE), "."
)
excluded_risk_years <- setdiff(risk_years_before_filter, unique(risks$Year))
if (length(excluded_risk_years) > 0) {
  message("Excluded non-comparable risk-score years: ", paste(excluded_risk_years, collapse = ", "))
}
if (!("Country.name" %in% names(sh_nat))) stop("Could not find Country.name / Country name in Shock counts data.")
if (!("Shock.category" %in% names(sh_nat))) stop("Could not find Shock.category / Shock category in Shock counts data.")
if (!("Shock.type" %in% names(sh_nat))) stop("Could not find Shock.type / Shock type in Shock counts data.")
if (!("count" %in% names(sh_nat))) stop("Could not find count in Shock counts data.")

sh_nat <- sh_nat %>%
  mutate(ISO3 = countrycode::countrycode(Country.name, "country.name", "iso3c"))

# Income groups from the wbstats cache, matching the original scripts.
meta <- tryCatch(wbstats::wb_cachelist$countries, error = function(e) NULL)
if (is.null(meta)) {
  meta <- tryCatch(wbstats::wb_countries(), error = function(e) NULL)
}
if (is.null(meta)) stop("Could not load World Bank country metadata from wbstats.")
if (!("income_level_iso3c" %in% names(meta))) {
  stop("The wbstats country metadata does not contain income_level_iso3c.")
}

inc_key <- meta %>% select(iso3c, income_level_iso3c)

sh_nat <- sh_nat %>%
  left_join(inc_key, by = c("ISO3" = "iso3c")) %>%
  rename(IncomeGroup = income_level_iso3c)

# Cleaning, as in the original scripts.
sh_nat <- sh_nat %>%
  filter(Shock.type != "Infestation", Year > (min(risks$Year, na.rm = TRUE) - 6)) %>%
  mutate(
    Shock.category = if_else(
      Shock.type == "Infectious disease" & Shock.category == "ECOLOGICAL",
      "DISEASES", Shock.category
    ),
    Shock.category = if_else(
      Shock.type == "Terrorist attack" & Shock.category == "CONFLICTS",
      "TERRORISM", Shock.category
    )
  )

end_years <- tibble::tribble(
  ~Shock.category, ~LastYear,
  "ECOLOGICAL", 2013,
  "DISEASES", 2022,
  "CLIMATIC", 2024,
  "TECHNOLOGICAL", 2024,
  "GEOPHYSICAL", 2024,
  "TERRORISM", 2020,
  "CONFLICTS", 2023,
  "ECONOMIC", 2019
)

# Category-specific coverage used in diagnostics that build annual shock tables.
# Within coverage, missing country/category/year combinations can be treated as
# observed zero counts. Beyond coverage, years are structural missing values and
# are not zero-filled.
analysis_first_year <- min(risks$Year, na.rm = TRUE) - max_lag
analysis_last_year <- max(end_years$LastYear, na.rm = TRUE)

shock_coverage <- end_years %>%
  mutate(
    Risk_Type = dplyr::recode(
      Shock.category, !!!map_risk,
      .default = as.character(Shock.category)
    ),
    Risk_Type = factor(Risk_Type, levels = risk_levels),
    FirstYear = analysis_first_year
  ) %>%
  filter(!is.na(Risk_Type), Risk_Type %in% risk_levels) %>%
  select(Risk_Type, FirstYear, LastYear) %>%
  distinct()

write.csv(
  shock_coverage,
  file.path(output_dir, "shock_category_coverage_used.csv"),
  row.names = FALSE
)

section13_window_settings <- tibble(
  setting = c(
    "INCLUDE_RISK_YEAR_IN_WINDOWS",
    "SECTION13_ALLOW_PARTIAL_WINDOWS",
    "SECTION13_MIN_WINDOW_OBSERVED_YEARS",
    "SECTION13_ROLLING_MEAN_REQUIRE_CENTER",
    "SECTION13_ROLLING_MEAN_MIN_NON_MISSING"
  ),
  value = c(
    as.character(INCLUDE_RISK_YEAR_IN_WINDOWS),
    as.character(SECTION13_ALLOW_PARTIAL_WINDOWS),
    as.character(SECTION13_MIN_WINDOW_OBSERVED_YEARS),
    as.character(SECTION13_ROLLING_MEAN_REQUIRE_CENTER),
    as.character(SECTION13_ROLLING_MEAN_MIN_NON_MISSING)
  )
)

write.csv(
  section13_window_settings,
  file.path(output_dir, "section13_window_settings_used.csv"),
  row.names = FALSE
)

sh_nat <- sh_nat %>%
  left_join(end_years, by = "Shock.category") %>%
  filter(Year <= LastYear) %>%
  select(-LastYear)

risks_long <- risks %>%
  pivot_longer(-Year, names_to = "Risk_Type", values_to = "Risk_Score") %>%
  mutate(Risk_Type = factor(Risk_Type, levels = risk_levels))

# Regional observed shock table used later for the GRR-year diagnostic.
sh_reg <- make_shocks_reg(sh_nat, reg_key, "category_first", "income", cutoff = TRUE) %>%
  mutate(
    Shock_Type = recode(as.character(Shock_Type), !!!map_risk, .default = as.character(Shock_Type)),
    Shock_Type = factor(Shock_Type, levels = risk_levels)
  )

lag_win <- tibble(
  Lag_Label = c(-1, 0, 1),
  Start_Offset = c(-5, -2, 1),
  End_Offset = c(-1, 2, 5)
)

# ----------------------------------------------------------------------
# 4. Load simulations and load/recompute observed regressions
# ----------------------------------------------------------------------

regional_sim_files <- first_complete_file_set(regional_sim_file_sets, "regional simulation outputs")
global_sim_files <- first_complete_file_set(global_sim_file_sets, "global simulation outputs")

message("Regional simulation files used:\n  ", paste(regional_sim_files, collapse = "\n  "))
message("Global simulation files used:\n  ", paste(global_sim_files, collapse = "\n  "))

res_lag_parallel <- load_and_bind_rdata(regional_sim_files, preferred_object = "res_lag_parallel")
reg_lag_parallel <- res_lag_parallel
res_glob_lag_parallel <- load_and_bind_rdata(global_sim_files, preferred_object = "res_glob_lag_parallel")

recompute_regional_observed <- function() {
  message("Recomputing observed regional expanding-window regressions from raw CSVs...")
  smoothed_reg_sets <- purrr::map(1:max_lag, function(w) {
    message("Preparing smoothed regional data for window = ", w)
    sh_tmp <- if (w == 1) sh_nat else smooth_nat_shocks(sh_nat, window = w)
    make_shocks_reg(
      sh_tmp, reg_key,
      method = "category_first",
      reg_level = "income",
      cutoff = TRUE
    ) %>%
      mutate(Shock_Type = recode(as.character(Shock_Type), !!!map_risk, .default = as.character(Shock_Type)))
  })
  names(smoothed_reg_sets) <- paste0("lag", 1:max_lag)
  
  regs <- unique(smoothed_reg_sets$lag1$Region)
  rtypes <- intersect(
    as.character(unique(risks_long$Risk_Type)),
    as.character(unique(smoothed_reg_sets$lag1$Shock_Type))
  )
  
  out <- purrr::pmap_dfr(
    tidyr::expand_grid(Region = regs, Risk_Type = rtypes),
    function(Region, Risk_Type) {
      run_reg_expand_reg(
        region = Region,
        rtype = Risk_Type,
        max_lag = max_lag,
        risks_long = risks_long,
        smoothed_reg_sets = smoothed_reg_sets,
        include0 = include0,
        min_n = min_n
      )
    }
  ) %>%
    filter_risk_score()
  
  save(out, file = file.path(output_dir, paste0("expanding_res_recomputed_", Sys.Date(), ".RData")))
  out
}

recompute_global_observed <- function() {
  message("Recomputing observed global expanding-window regressions from raw CSVs...")
  smoothed_glob_sets <- purrr::map(1:max_lag, function(w) {
    message("Preparing smoothed global data for window = ", w)
    sh_tmp <- if (w == 1) sh_nat else smooth_nat_shocks(sh_nat, window = w)
    make_shocks_global(
      sh_tmp,
      method = "category_first",
      cutoff = TRUE
    ) %>%
      mutate(Shock_Type = recode(as.character(Shock_Type), !!!map_risk, .default = as.character(Shock_Type)))
  })
  names(smoothed_glob_sets) <- paste0("lag", 1:max_lag)
  
  rtypes <- intersect(
    as.character(unique(risks_long$Risk_Type)),
    as.character(unique(smoothed_glob_sets$lag1$Shock_Type))
  )
  
  out <- purrr::map_dfr(
    rtypes,
    ~ run_reg_expand_glob(
      rtype = .x,
      max_lag = max_lag,
      risks_long = risks_long,
      smoothed_glob_sets = smoothed_glob_sets,
      include0 = include0,
      min_n = min_n
    )
  ) %>%
    filter_risk_score()
  
  save(out, file = file.path(output_dir, paste0("glob_expanding_res_recomputed_", Sys.Date(), ".RData")))
  out
}

regional_regression_file <- if (isTRUE(FORCE_RECOMPUTE_OBSERVED_REGRESSIONS)) {
  NA_character_
} else {
  find_existing_file(regional_regression_files)
}
if (!is.na(regional_regression_file)) {
  res_reg_expand_fast <- load_rdata_flexible(regional_regression_file, preferred_object = "res_reg_expand_fast")
} else {
  warning("Regional observed-regression RData file not found. The script will recompute it from raw CSVs.")
  res_reg_expand_fast <- recompute_regional_observed()
}

global_regression_file <- if (isTRUE(FORCE_RECOMPUTE_OBSERVED_REGRESSIONS)) {
  NA_character_
} else {
  find_existing_file(global_regression_files)
}
if (!is.na(global_regression_file)) {
  res_glob_expand_fast <- load_rdata_flexible(global_regression_file, preferred_object = "res_glob_expand_fast")
} else {
  warning("Global observed-regression RData file not found. The script will recompute it from raw CSVs.")
  res_glob_expand_fast <- recompute_global_observed()
}

message("Loaded/recomputed simulation and regression objects.")

# ----------------------------------------------------------------------
# 5. Build observed-vs-simulation comparison tables
# ----------------------------------------------------------------------

# Global simulation summaries.
sim_expand_glob_sum <- filter_risk_score(res_glob_lag_parallel) %>%
  group_by(Risk_Type, Lag) %>%
  summarise(
    mean_sim = mean(estimate, na.rm = TRUE),
    sd_sim = sd(estimate, na.rm = TRUE),
    q025 = quantile(estimate, SIM_ENVELOPE_LOWER, na.rm = TRUE),
    q975 = quantile(estimate, SIM_ENVELOPE_UPPER, na.rm = TRUE),
    .groups = "drop"
  )

comp_glob_expand <- filter_risk_score(res_glob_expand_fast) %>%
  rename(real_est = estimate) %>%
  left_join(sim_expand_glob_sum, by = c("Risk_Type", "Lag")) %>%
  mutate(
    z = if_else(is.finite(sd_sim) & sd_sim > 0, (real_est - mean_sim) / sd_sim, NA_real_),
    signif = real_est < q025 | real_est > q975,
    sig.two = case_when(
      signif & p.value < 0.05 ~ "BOTH",
      signif & p.value >= 0.05 ~ "SIM",
      !signif & p.value < 0.05 ~ "REG",
      TRUE ~ "NONE"
    ),
    sig.two = factor(sig.two, levels = c("BOTH", "SIM", "REG", "NONE")),
    Risk_Type = factor(Risk_Type, levels = risk_levels)
  )

# Regional simulation summaries.
sim_expand_smooth_sum <- filter_risk_score(res_lag_parallel) %>%
  group_by(Region, Risk_Type, Lag) %>%
  summarise(
    mean_sim = mean(estimate, na.rm = TRUE),
    sd_sim = sd(estimate, na.rm = TRUE),
    q025 = quantile(estimate, SIM_ENVELOPE_LOWER, na.rm = TRUE),
    q975 = quantile(estimate, SIM_ENVELOPE_UPPER, na.rm = TRUE),
    .groups = "drop"
  )

comp_reg_expand <- filter_risk_score(res_reg_expand_fast) %>%
  rename(real_est = estimate) %>%
  left_join(sim_expand_smooth_sum, by = c("Region", "Risk_Type", "Lag")) %>%
  mutate(
    z = if_else(is.finite(sd_sim) & sd_sim > 0, (real_est - mean_sim) / sd_sim, NA_real_),
    signif = real_est < q025 | real_est > q975,
    sig.two = case_when(
      signif & p.value < 0.05 ~ "BOTH",
      signif & p.value >= 0.05 ~ "SIM",
      !signif & p.value < 0.05 ~ "REG",
      TRUE ~ "NONE"
    ),
    sig.two = factor(sig.two, levels = c("BOTH", "SIM", "REG", "NONE")),
    Region = factor(Region, levels = income_levels),
    Risk_Type = factor(Risk_Type, levels = risk_levels)
  )

# Combine regional and global coefficient tables.
comp_glob_tagged <- comp_glob_expand %>%
  mutate(Region = factor("Global", levels = region_levels))

comp_all_expand <- bind_rows(comp_reg_expand, comp_glob_tagged) %>%
  mutate(
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

# Export the main lag-level observed-vs-null tables used for Figure 1/S6 and
# for the derived predictive-capacity/anticipatory-skill metrics. These files
# make the figure classifications and lag-level coefficients auditable without
# reopening the RData objects.
write.csv(
  comp_glob_expand,
  file.path(output_dir, "global_lag_coefficients_observed_vs_simulation.csv"),
  row.names = FALSE
)
write.csv(
  comp_reg_expand,
  file.path(output_dir, "income_group_lag_coefficients_observed_vs_simulation.csv"),
  row.names = FALSE
)
write.csv(
  comp_all_expand,
  file.path(output_dir, "all_regions_lag_coefficients_observed_vs_simulation.csv"),
  row.names = FALSE
)
write.csv(
  sim_expand_glob_sum,
  file.path(output_dir, "global_lag_simulation_summary.csv"),
  row.names = FALSE
)
write.csv(
  sim_expand_smooth_sum,
  file.path(output_dir, "income_group_lag_simulation_summary.csv"),
  row.names = FALSE
)

# ----------------------------------------------------------------------
# 6. Compute predictive capacity and anticipatory skill
# ----------------------------------------------------------------------

compute_metric_summary <- function(dat) {
  dat %>%
    group_by(Region, term, Risk_Type) %>%
    reframe({
      fut_mask <- Lag %in% 1:5
      v_future <- ifelse(fut_mask, real_est, -Inf)
      
      if (!any(is.finite(v_future))) {
        tibble(
          lag_max = NA_integer_,
          max_future = NA_real_,
          corr_past = NA_real_,
          diff_future_corrpast = NA_real_
        )
      } else {
        i <- which.max(v_future)
        lag_pos <- Lag[i]
        max_fut <- real_est[i]
        j <- which(Lag == -lag_pos)
        past_val <- if (length(j)) real_est[j[1]] else NA_real_
        tibble(
          lag_max = lag_pos,
          max_future = max_fut,
          corr_past = past_val,
          diff_future_corrpast = max_fut - past_val
        )
      }
    }) %>%
    ungroup() %>%
    mutate(
      Region = factor(as.character(Region), levels = region_levels),
      Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
    )
}

comp_summary_all <- compute_metric_summary(comp_all_expand)

write.csv(
  comp_summary_all,
  file.path(output_dir, "Predictive_and_anticipatory_capacity_and_best_recomputed.csv"),
  row.names = FALSE
)

# Target risks for the main income-group comparison. The reviewer-facing
# inference is restricted to risks with positive global predictive capacity,
# because anticipatory skill is not meaningful when global future alignment is
# negative. In the current data these are Climate, Diseases, Conflicts, and
# Terrorism.
global_target_risk_check <- comp_summary_all %>%
  filter(term == "Risk_Score", Region == "Global") %>%
  transmute(
    Risk_Type = as.character(Risk_Type),
    display_risk = risk_label(Risk_Type),
    global_predictive_capacity = max_future,
    global_anticipatory_skill = diff_future_corrpast,
    positive_global_predictive_capacity = max_future > 0,
    selected_for_targeted_income_tests = Risk_Type %in% TARGET_RISKS_POSITIVE_GLOBAL
  ) %>%
  arrange(match(Risk_Type, risk_levels))

target_risks_auto <- global_target_risk_check %>%
  filter(positive_global_predictive_capacity) %>%
  arrange(match(Risk_Type, risk_levels)) %>%
  pull(Risk_Type)

target_risks <- intersect(risk_levels, TARGET_RISKS_POSITIVE_GLOBAL)

if (!setequal(target_risks, target_risks_auto)) {
  warning(
    "The manually selected target risks do not exactly match the risks with positive global predictive capacity. ",
    "Manual target risks: ", paste(risk_label(target_risks), collapse = ", "),
    ". Auto-positive global risks: ", paste(risk_label(target_risks_auto), collapse = ", "),
    ". Check revision_outputs_predictive_analysis/global_target_risk_selection_check.csv."
  )
}

target_risk_label <- paste(risk_label(target_risks), collapse = ", ")
write.csv(
  global_target_risk_check,
  file.path(output_dir, "global_target_risk_selection_check.csv"),
  row.names = FALSE
)

# ----------------------------------------------------------------------
# 7. Revised Figure 1: global lag coefficients with legend in lower right
# ----------------------------------------------------------------------

figure1_global <- ggplot(comp_glob_expand, aes(x = Lag, y = real_est)) +
  geom_ribbon(
    aes(ymin = q025, ymax = q975),
    fill = "grey70", alpha = 0.25, colour = NA
  ) +
  geom_line(alpha = 0.7, linewidth = 0.7) +
  geom_point(aes(colour = sig.two), size = 2.8) +
  facet_wrap(~ Risk_Type, ncol = 3, labeller = labeller(Risk_Type = as_labeller(risk_label))) +
  geom_hline(yintercept = 0, linewidth = 0.35) +
  geom_vline(xintercept = 0, linewidth = 0.35) +
  scale_colour_manual(values = sig_pal, drop = FALSE) +
  scale_x_continuous(breaks = c(-5, -2.5, 0, 2.5, 5)) +
  labs(
    y = "Coefficient (observed shocks vs. simulated 2.5–97.5% envelope)",
    x = "Max lag (years)",
    colour = "Significant (P < 0.05)"
  ) +
  theme_bw(base_size = 12) +
  theme(
    panel.grid.major = element_line(color = "grey85", linewidth = 0.25),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(1, "lines"),
    strip.text = element_text(face = "bold", size = 12),
    strip.background = element_rect(fill = "grey92", colour = "grey60"),
    legend.position = c(0.84, 0.16),
    legend.justification = c("center", "center"),
    legend.background = element_rect(fill = "white", colour = "grey80"),
    legend.key = element_blank(),
    legend.title = element_text(size = 11),
    legend.text = element_text(size = 10)
  )

save_plot(figure1_global, "Figure_1_global_revised", width = 7.2, height = 7.0)

# ----------------------------------------------------------------------
# 8. Regional lag plot, equivalent to original Figure S6
# ----------------------------------------------------------------------

figure_s6_regional <- ggplot(comp_reg_expand, aes(x = Lag, y = real_est)) +
  geom_ribbon(aes(fill = Region, ymin = q025, ymax = q975), alpha = 0.30, colour = NA) +
  geom_line(aes(group = Region), alpha = 0.45, linewidth = 0.45) +
  geom_point(aes(colour = sig.two), size = 1.7) +
  facet_grid(Region ~ Risk_Type, labeller = labeller(Risk_Type = as_labeller(risk_label))) +
  geom_hline(yintercept = 0, linewidth = 0.30) +
  geom_vline(xintercept = 0, linewidth = 0.30) +
  scale_colour_manual(values = sig_pal, drop = FALSE) +
  scale_x_continuous(breaks = c(-5, -2.5, 0, 2.5, 5)) +
  labs(
    y = "Coefficient (observed shocks vs. simulated 95% envelope)",
    x = "Max lag (years)",
    colour = "Significant (P < 0.05)",
    fill = "Region"
  ) +
  theme_bw(base_size = 10) +
  theme(
    panel.grid.major = element_line(color = "grey88", linewidth = 0.20),
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = "grey70"),
    legend.position = "right"
  )

save_plot(figure_s6_regional, "Figure_S6_regional_simulation_results_revised", width = 12, height = 8)

# ----------------------------------------------------------------------
# 9. Revised Figure 2 top panels
# ----------------------------------------------------------------------

y_lims <- pad_limits(comp_summary_all$diff_future_corrpast, pad = 0.08, include_zero = TRUE)
x_lims <- pad_limits(comp_summary_all$max_future, pad = 0.08, include_zero = TRUE)

base_fig2_theme <- theme_bw(base_size = 11) +
  theme(
    panel.grid.major = element_line(color = "grey88", linewidth = 0.25),
    panel.grid.minor = element_blank(),
    legend.position = "right",
    legend.key = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = "grey70")
  )

fig2_top_left <- ggplot(
  comp_summary_all,
  aes(x = max_future, y = diff_future_corrpast, color = Risk_Type)
) +
  geom_hline(yintercept = 0, color = "grey60", linewidth = 0.35) +
  geom_vline(xintercept = 0, color = "grey60", linewidth = 0.35) +
  geom_path(aes(group = Risk_Type), linetype = "dashed", linewidth = 0.35, alpha = 0.6) +
  geom_point(
    data = filter(comp_summary_all, Region != "Global"),
    aes(shape = Region), size = 2.6, stroke = 0.9
  ) +
  geom_point(
    data = filter(comp_summary_all, Region == "Global"),
    aes(shape = Region), size = 4.8, stroke = 1.2
  ) +
  scale_color_manual(values = risk_pal, breaks = risk_levels, labels = risk_label(risk_levels), drop = FALSE) +
  scale_shape_manual(values = region_shapes, drop = FALSE) +
  coord_cartesian(xlim = x_lims, ylim = y_lims) +
  labs(
    x = "Predictive capacity (max. future coefficient)",
    y = "Anticipatory skill (future - past)",
    color = "Risk",
    shape = "Region"
  ) +
  base_fig2_theme

fig2_top_right <- ggplot(
  comp_summary_all,
  aes(x = lag_max, y = diff_future_corrpast, color = Risk_Type)
) +
  geom_hline(yintercept = 0, color = "grey60", linewidth = 0.35) +
  geom_path(aes(group = Risk_Type), linetype = "dashed", linewidth = 0.35, alpha = 0.6) +
  geom_point(
    data = filter(comp_summary_all, Region != "Global"),
    aes(shape = Region), size = 2.6, stroke = 0.9
  ) +
  geom_point(
    data = filter(comp_summary_all, Region == "Global"),
    aes(shape = Region), size = 4.8, stroke = 1.2
  ) +
  scale_color_manual(values = risk_pal, breaks = risk_levels, labels = risk_label(risk_levels), drop = FALSE) +
  scale_shape_manual(values = region_shapes, drop = FALSE) +
  scale_x_continuous(limits = c(0.7, 5.3), breaks = 1:5, expand = expansion(mult = 0)) +
  coord_cartesian(ylim = y_lims) +
  labs(
    x = "Time horizon (years)",
    y = "Anticipatory skill (future - past)",
    color = "Risk",
    shape = "Region"
  ) +
  base_fig2_theme

save_plot(fig2_top_left, "Figure_2_top_left_revised", width = 4.6, height = 3.8)
save_plot(fig2_top_right, "Figure_2_top_right_revised", width = 4.6, height = 3.8)

# ----------------------------------------------------------------------
# 10. Targeted statistical tests for income-group differences
# ----------------------------------------------------------------------

# Main revision choice: restrict the income-group comparison to the four risk
# categories with positive global predictive capacity. This avoids testing
# anticipatory skill for categories in which the global analysis has no positive
# future alignment to begin with.

income_summary <- comp_summary_all %>%
  filter(term == "Risk_Score", Region %in% income_levels) %>%
  mutate(
    Region = factor(as.character(Region), levels = income_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

income_summary_targeted <- income_summary %>%
  filter(as.character(Risk_Type) %in% target_risks) %>%
  mutate(Risk_Type = factor(as.character(Risk_Type), levels = target_risks))

metric_label_from_name <- function(metric) {
  dplyr::recode(
    metric,
    "diff_future_corrpast" = "Anticipatory skill",
    "max_future" = "Predictive capacity",
    .default = metric
  )
}

friedman_region_test <- function(dat, metric, region_levels = income_levels) {
  wide <- dat %>%
    select(Risk_Type, Region, value = all_of(metric)) %>%
    mutate(Region = as.character(Region), Risk_Type = as.character(Risk_Type)) %>%
    pivot_wider(names_from = Region, values_from = value) %>%
    arrange(match(Risk_Type, risk_levels))
  
  missing_regions <- setdiff(region_levels, names(wide))
  if (length(missing_regions) > 0) {
    stop("Missing region columns in Friedman test: ", paste(missing_regions, collapse = ", "))
  }
  
  wide_complete <- wide %>% tidyr::drop_na(all_of(region_levels))
  mat <- as.matrix(wide_complete[, region_levels])
  rownames(mat) <- wide_complete$Risk_Type
  
  if (nrow(mat) < 2) {
    stop("Friedman test requires at least two complete risk-category blocks.")
  }
  
  fried <- friedman.test(mat)
  
  ranks_mat <- t(apply(mat, 1, function(z) rank(z, ties.method = "average")))
  colnames(ranks_mat) <- region_levels
  rownames(ranks_mat) <- rownames(mat)
  
  rank_long <- as.data.frame(ranks_mat) %>%
    tibble::rownames_to_column("Risk_Type") %>%
    pivot_longer(all_of(region_levels), names_to = "Region", values_to = "rank") %>%
    mutate(
      Region = factor(Region, levels = region_levels),
      Risk_Type = factor(Risk_Type, levels = risk_levels),
      metric = metric,
      metric_label = metric_label_from_name(metric)
    )
  
  mean_rank <- rank_long %>%
    group_by(metric, metric_label, Region) %>%
    summarise(mean_rank = mean(rank, na.rm = TRUE), .groups = "drop")
  
  list(
    summary = tibble(
      metric = metric,
      metric_label = metric_label_from_name(metric),
      n_risk_categories = nrow(mat),
      risk_categories = paste(risk_label(rownames(mat)), collapse = ", "),
      statistic = unname(fried$statistic),
      df = unname(fried$parameter),
      p_value = fried$p.value
    ),
    values_wide = wide_complete,
    rank_long = rank_long,
    mean_rank = mean_rank
  )
}

targeted_predictive_test <- friedman_region_test(income_summary_targeted, "max_future")
targeted_anticipatory_test <- friedman_region_test(income_summary_targeted, "diff_future_corrpast")

# Order anticipatory first in the output text, then predictive.
income_test_summary_targeted <- bind_rows(
  targeted_anticipatory_test$summary,
  targeted_predictive_test$summary
)

income_rank_long_targeted <- bind_rows(
  targeted_anticipatory_test$rank_long,
  targeted_predictive_test$rank_long
)

income_mean_rank_targeted <- bind_rows(
  targeted_anticipatory_test$mean_rank,
  targeted_predictive_test$mean_rank
)

income_metric_values_targeted <- income_summary_targeted %>%
  select(Risk_Type, Region, max_future, diff_future_corrpast) %>%
  mutate(display_risk = risk_label(Risk_Type)) %>%
  relocate(display_risk, .after = Risk_Type)

write.csv(
  income_test_summary_targeted,
  file.path(output_dir, "income_group_friedman_tests_targeted_positive_global_risks.csv"),
  row.names = FALSE
)
write.csv(
  income_metric_values_targeted,
  file.path(output_dir, "income_group_metric_values_targeted_positive_global_risks.csv"),
  row.names = FALSE
)
write.csv(
  income_rank_long_targeted,
  file.path(output_dir, "income_group_ranks_targeted_positive_global_risks.csv"),
  row.names = FALSE
)
write.csv(
  income_mean_rank_targeted,
  file.path(output_dir, "income_group_mean_ranks_targeted_positive_global_risks.csv"),
  row.names = FALSE
)

# Optional all-risk sensitivity tables for transparency. These are not the main
# inference and should not drive the revision text.
if (isTRUE(MAKE_ALL_RISK_SENSITIVITY_TABLES)) {
  allrisk_predictive_test <- friedman_region_test(income_summary, "max_future")
  allrisk_anticipatory_test <- friedman_region_test(income_summary, "diff_future_corrpast")
  income_test_summary_allrisks <- bind_rows(
    allrisk_anticipatory_test$summary,
    allrisk_predictive_test$summary
  )
  write.csv(
    income_test_summary_allrisks,
    file.path(output_dir, "income_group_friedman_tests_all_8_risks_sensitivity.csv"),
    row.names = FALSE
  )
}

# Figure A: raw values for the targeted income-group comparison.
income_profile_target_long <- income_summary_targeted %>%
  select(Risk_Type, Region, max_future, diff_future_corrpast) %>%
  pivot_longer(
    cols = c(max_future, diff_future_corrpast),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric_label = metric_label_from_name(metric),
    display_risk = risk_label(Risk_Type)
  )

friedman_labs_targeted <- income_test_summary_targeted %>%
  mutate(
    label = paste0(
      "Friedman chi-square = ", sprintf("%.1f", statistic),
      ", df = ", df, ", ", format_p(p_value)
    ),
    Region = factor("HIC", levels = income_levels),
    value = Inf
  )

figure_income_targeted_values <- ggplot(
  income_profile_target_long,
  aes(x = Region, y = value, group = Risk_Type, colour = Risk_Type)
) +
  geom_hline(yintercept = 0, linewidth = 0.30, colour = "grey60") +
  geom_line(alpha = 0.72, linewidth = 0.55) +
  geom_point(size = 2.5) +
  geom_point(
    data = filter(income_profile_target_long, Region == "HIC"),
    size = 3.5, shape = 21, fill = "white", stroke = 1.0
  ) +
  geom_text(
    data = friedman_labs_targeted,
    aes(x = Region, y = value, label = label),
    inherit.aes = FALSE,
    hjust = 0,
    vjust = 1.25,
    size = 3.1
  ) +
  facet_wrap(~ metric_label, scales = "free_y", ncol = 1) +
  scale_colour_manual(values = risk_pal, breaks = target_risks, labels = risk_label(target_risks), drop = FALSE) +
  coord_cartesian(clip = "off") +
  labs(
    x = "Income group",
    y = "Metric value",
    colour = "Risk category"
  ) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "right",
    strip.background = element_rect(fill = "grey92", colour = "grey70"),
    plot.margin = margin(5.5, 18, 5.5, 5.5)
  )

save_plot(
  figure_income_targeted_values,
  "Figure_S_income_group_targeted_metric_profiles",
  width = 8.0,
  height = 6.2
)

# Figure B: Friedman ranks. This directly displays the information used by the
# omnibus test: within each risk category, rank 4 is the highest value.
figure_income_targeted_ranks <- ggplot(
  income_rank_long_targeted,
  aes(x = Region, y = rank, group = Risk_Type, colour = Risk_Type)
) +
  geom_line(alpha = 0.60, linewidth = 0.45) +
  geom_point(size = 2.3) +
  geom_point(
    data = income_mean_rank_targeted,
    aes(x = Region, y = mean_rank, shape = "Mean rank"),
    inherit.aes = FALSE,
    size = 4.2,
    fill = "white",
    colour = "black",
    stroke = 1.0
  ) +
  geom_text(
    data = income_mean_rank_targeted,
    aes(x = Region, y = mean_rank, label = sprintf("%.2f", mean_rank)),
    inherit.aes = FALSE,
    vjust = -0.9,
    size = 2.8
  ) +
  facet_wrap(~ metric_label, ncol = 1) +
  scale_y_continuous(breaks = 1:4, limits = c(0.75, 4.35)) +
  scale_colour_manual(values = risk_pal, breaks = target_risks, labels = risk_label(target_risks), drop = FALSE) +
  scale_shape_manual(values = c("Mean rank" = 23), name = NULL) +
  guides(
    colour = guide_legend(order = 1, override.aes = list(size = 2.8)),
    shape = guide_legend(order = 2, override.aes = list(fill = "white", colour = "black", size = 4.2))
  ) +
  labs(
    x = "Income group",
    y = "Within-risk rank (1 = lowest, 4 = highest)",
    colour = "Risk category"
  ) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "right",
    strip.background = element_rect(fill = "grey92", colour = "grey70")
  )

save_plot(
  figure_income_targeted_ranks,
  "Figure_S_income_group_targeted_friedman_ranks",
  width = 8.0,
  height = 6.2
)

# ----------------------------------------------------------------------
# 11. Parametric confidence intervals for derived metrics
# ----------------------------------------------------------------------

metric_from_lag_table <- function(dat, estimate_col = "real_est") {
  dat <- dat %>%
    filter(!is.na(.data[[estimate_col]]), Lag != 0)
  
  fut <- dat %>% filter(Lag %in% 1:5)
  
  if (nrow(fut) == 0 || all(is.na(fut[[estimate_col]]))) {
    return(tibble(
      lag_max = NA_integer_,
      max_future = NA_real_,
      corr_past = NA_real_,
      diff_future_corrpast = NA_real_
    ))
  }
  
  i <- which.max(fut[[estimate_col]])
  lag_pos <- fut$Lag[i]
  max_fut <- fut[[estimate_col]][i]
  
  past_val <- dat %>%
    filter(Lag == -lag_pos) %>%
    slice(1) %>%
    pull(all_of(estimate_col))
  
  if (length(past_val) == 0) past_val <- NA_real_
  
  tibble(
    lag_max = lag_pos,
    max_future = max_fut,
    corr_past = past_val,
    diff_future_corrpast = max_fut - past_val
  )
}

metric_ci_parametric <- function(dat, B = 10000) {
  if (!("std.error" %in% names(dat))) {
    stop("The regression table must contain std.error to compute parametric CIs.")
  }
  
  obs <- metric_from_lag_table(dat, estimate_col = "real_est")
  
  draws <- map_dfr(seq_len(B), function(b) {
    dat_b <- dat %>%
      mutate(
        draw_est = rnorm(
          n = n(),
          mean = real_est,
          sd = ifelse(is.na(std.error), 0, std.error)
        )
      )
    metric_from_lag_table(dat_b, estimate_col = "draw_est") %>% mutate(draw = b)
  })
  
  tibble(
    lag_max = obs$lag_max,
    max_future = obs$max_future,
    max_future_lwr = quantile(draws$max_future, 0.025, na.rm = TRUE),
    max_future_upr = quantile(draws$max_future, 0.975, na.rm = TRUE),
    corr_past = obs$corr_past,
    diff_future_corrpast = obs$diff_future_corrpast,
    diff_future_corrpast_lwr = quantile(draws$diff_future_corrpast, 0.025, na.rm = TRUE),
    diff_future_corrpast_upr = quantile(draws$diff_future_corrpast, 0.975, na.rm = TRUE)
  )
}

if ("std.error" %in% names(comp_all_expand)) {
  ci_parametric <- comp_all_expand %>%
    filter(term == "Risk_Score") %>%
    group_by(Region, Risk_Type) %>%
    group_modify(~ metric_ci_parametric(.x, B = B_PARAMETRIC_CI)) %>%
    ungroup() %>%
    mutate(
      Region = factor(as.character(Region), levels = region_levels),
      Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
    )
  
  write.csv(ci_parametric, file.path(output_dir, "metric_parametric_coefficient_draw_CI.csv"), row.names = FALSE)
  
  ci_parametric_long <- bind_rows(
    ci_parametric %>%
      transmute(
        Region, Risk_Type,
        metric = "Predictive capacity",
        estimate = max_future,
        lwr = max_future_lwr,
        upr = max_future_upr
      ),
    ci_parametric %>%
      transmute(
        Region, Risk_Type,
        metric = "Anticipatory skill",
        estimate = diff_future_corrpast,
        lwr = diff_future_corrpast_lwr,
        upr = diff_future_corrpast_upr
      )
  )
  
  figure_parametric_ci <- ggplot(ci_parametric_long, aes(y = Risk_Type, x = estimate, colour = Risk_Type)) +
    geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.35) +
    geom_segment(aes(x = lwr, xend = upr, y = Risk_Type, yend = Risk_Type), linewidth = 0.8) +
    geom_point(size = 2.2) +
    facet_grid(metric ~ Region, scales = "free_x") +
    scale_colour_manual(values = risk_pal, breaks = risk_levels, labels = risk_label(risk_levels), drop = FALSE, guide = "none") +
    scale_y_discrete(labels = risk_label) +
    labs(
      x = "Observed metric with 95% coefficient-draw interval",
      y = "Risk category"
    ) +
    theme_bw(base_size = 10) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "grey92", colour = "grey70")
    )
  
  save_plot(figure_parametric_ci, "Figure_S_metric_parametric_CI_all_risks", width = 10.5, height = 5.2)
  
} else {
  warning("std.error is not available in comp_all_expand; skipping parametric CI figure.")
}

# ----------------------------------------------------------------------
# 12. Randomization/null intervals for derived metrics
# ----------------------------------------------------------------------

detect_sim_col <- function(x) {
  candidates <- c(
    "sim_id", "simulation", "Simulation", "sim", "Sim",
    "iter", "iteration", "replicate", ".rep", "rand_id", "id"
  )
  found <- intersect(candidates, names(x))
  if (length(found) > 0) found[1] else NA_character_
}

add_sim_id_if_missing <- function(x, group_vars) {
  sim_col <- detect_sim_col(x)
  
  if (!is.na(sim_col)) {
    x %>% rename(sim_id = all_of(sim_col))
  } else {
    warning(
      "No simulation-id column detected. Creating sim_id by row order within ",
      paste(group_vars, collapse = ", "),
      " and Lag. This assumes the simulation rows are aligned across lags. ",
      "For the cleanest final analysis, add sim_id in the original simulation worker."
    )
    
    x %>%
      group_by(across(all_of(c(group_vars, "Lag")))) %>%
      mutate(sim_id = row_number()) %>%
      ungroup()
  }
}

metric_from_simulation <- function(dat) {
  dat <- dat %>% filter(!is.na(estimate), Lag != 0)
  fut <- dat %>% filter(Lag %in% 1:5)
  
  if (nrow(fut) == 0 || all(is.na(fut$estimate))) {
    return(tibble(
      lag_max = NA_integer_,
      max_future = NA_real_,
      corr_past = NA_real_,
      diff_future_corrpast = NA_real_
    ))
  }
  
  i <- which.max(fut$estimate)
  lag_pos <- fut$Lag[i]
  max_fut <- fut$estimate[i]
  
  past_val <- dat %>%
    filter(Lag == -lag_pos) %>%
    slice(1) %>%
    pull(estimate)
  
  if (length(past_val) == 0) past_val <- NA_real_
  
  tibble(
    lag_max = lag_pos,
    max_future = max_fut,
    corr_past = past_val,
    diff_future_corrpast = max_fut - past_val
  )
}

sim_reg_for_metrics <- filter_risk_score(res_lag_parallel) %>%
  add_sim_id_if_missing(group_vars = c("Region", "Risk_Type")) %>%
  mutate(sim_id = as.character(sim_id))

sim_glob_for_metrics <- filter_risk_score(res_glob_lag_parallel) %>%
  mutate(Region = "Global") %>%
  add_sim_id_if_missing(group_vars = c("Region", "Risk_Type")) %>%
  mutate(sim_id = as.character(sim_id))

sim_all_for_metrics <- bind_rows(sim_reg_for_metrics, sim_glob_for_metrics) %>%
  mutate(
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

sim_metric_null <- sim_all_for_metrics %>%
  group_by(sim_id, Region, Risk_Type) %>%
  group_modify(~ metric_from_simulation(.x)) %>%
  ungroup()

null_intervals <- sim_metric_null %>%
  group_by(Region, Risk_Type) %>%
  summarise(
    null_max_future_q025 = quantile(max_future, 0.025, na.rm = TRUE),
    null_max_future_q50 = quantile(max_future, 0.50, na.rm = TRUE),
    null_max_future_q975 = quantile(max_future, 0.975, na.rm = TRUE),
    null_skill_q025 = quantile(diff_future_corrpast, 0.025, na.rm = TRUE),
    null_skill_q50 = quantile(diff_future_corrpast, 0.50, na.rm = TRUE),
    null_skill_q975 = quantile(diff_future_corrpast, 0.975, na.rm = TRUE),
    .groups = "drop"
  )

robust_metric_summary <- comp_summary_all %>%
  filter(term == "Risk_Score") %>%
  left_join(null_intervals, by = c("Region", "Risk_Type")) %>%
  mutate(
    max_future_outside_null =
      max_future < null_max_future_q025 | max_future > null_max_future_q975,
    skill_outside_null =
      diff_future_corrpast < null_skill_q025 | diff_future_corrpast > null_skill_q975
  )

write.csv(robust_metric_summary, file.path(output_dir, "metric_randomization_intervals_and_tests.csv"), row.names = FALSE)

robust_metric_long <- bind_rows(
  robust_metric_summary %>%
    transmute(
      Region, Risk_Type,
      metric = "Predictive capacity",
      estimate = max_future,
      lwr = null_max_future_q025,
      upr = null_max_future_q975,
      outside_null = max_future_outside_null
    ),
  robust_metric_summary %>%
    transmute(
      Region, Risk_Type,
      metric = "Anticipatory skill",
      estimate = diff_future_corrpast,
      lwr = null_skill_q025,
      upr = null_skill_q975,
      outside_null = skill_outside_null
    )
) %>%
  mutate(
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

figure_randomization_ci <- ggplot(robust_metric_long, aes(y = Risk_Type, x = estimate, colour = Risk_Type)) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.35) +
  geom_segment(aes(x = lwr, xend = upr, y = Risk_Type, yend = Risk_Type), linewidth = 0.8, alpha = 0.85) +
  geom_point(aes(shape = outside_null), size = 2.4) +
  facet_grid(metric ~ Region, scales = "free_x") +
  scale_colour_manual(values = risk_pal, breaks = risk_levels, labels = risk_label(risk_levels), drop = FALSE, guide = "none") +
  scale_y_discrete(labels = risk_label) +
  scale_shape_manual(
    values = c("TRUE" = 19, "FALSE" = 1),
    labels = c("FALSE" = "Inside null interval", "TRUE" = "Outside null interval"),
    name = NULL
  ) +
  labs(
    x = "Observed metric vs. 95% Monte Carlo null interval",
    y = "Risk category"
  ) +
  theme_bw(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    strip.background = element_rect(fill = "grey92", colour = "grey70")
  )

save_plot(figure_randomization_ci, "Figure_S_metric_randomization_intervals_all_risks", width = 10.5, height = 5.4)


# ----------------------------------------------------------------------
# 13. GRR-year performance: which editions perform best?
# ----------------------------------------------------------------------
# This section computes edition-level predictive capacity using regression
# coefficients across risk categories within each GRR year. For each year and
# horizon, it regresses future shocks across risk categories on GRR risk scores,
# then keeps the horizon with the maximum future coefficient. Anticipatory skill
# subtracts the past-window coefficient at the same horizon.
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(broom)
  library(tibble)
})

required_objects_13 <- c(
  "sh_reg", "sh_nat", "risks_long", "map_risk", "risk_levels",
  "region_levels", "income_levels", "output_dir",
  "shock_coverage", "analysis_first_year", "analysis_last_year"
)

missing_objects_13 <- required_objects_13[
  !vapply(required_objects_13, exists, logical(1))
]

if (length(missing_objects_13) > 0) {
  stop(
    "Run the master script through Section 12 first. Missing object(s): ",
    paste(missing_objects_13, collapse = ", ")
  )
}

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

if (!exists("INCLUDE_RISK_YEAR_IN_WINDOWS")) {
  INCLUDE_RISK_YEAR_IN_WINDOWS <- TRUE
}
if (!exists("SECTION13_ALLOW_PARTIAL_WINDOWS")) {
  SECTION13_ALLOW_PARTIAL_WINDOWS <- TRUE
}
if (!exists("SECTION13_MIN_WINDOW_OBSERVED_YEARS")) {
  SECTION13_MIN_WINDOW_OBSERVED_YEARS <- 1L
}
if (!exists("SECTION13_ROLLING_MEAN_REQUIRE_CENTER")) {
  SECTION13_ROLLING_MEAN_REQUIRE_CENTER <- TRUE
}
if (!exists("SECTION13_ROLLING_MEAN_MIN_NON_MISSING")) {
  SECTION13_ROLLING_MEAN_MIN_NON_MISSING <- 1L
}
message(
  "Section 13 inclusive-window setting: INCLUDE_RISK_YEAR_IN_WINDOWS = ",
  INCLUDE_RISK_YEAR_IN_WINDOWS
)
message(
  "Section 13 partial-window setting: SECTION13_ALLOW_PARTIAL_WINDOWS = ",
  SECTION13_ALLOW_PARTIAL_WINDOWS,
  "; SECTION13_MIN_WINDOW_OBSERVED_YEARS = ",
  SECTION13_MIN_WINDOW_OBSERVED_YEARS
)

if (!exists("risk_label")) {
  risk_label <- function(x) {
    dplyr::recode(
      as.character(x),
      "Geophysical" = "Geophysical",
      "Climate" = "Climate",
      "Diseases" = "Diseases",
      "Food" = "Food",
      "Economic" = "Economic",
      "GeoConflict" = "Conflicts",
      "Terror" = "Terrorism",
      "Tech" = "Technology",
      .default = as.character(x)
    )
  }
}

if (!exists("save_plot")) {
  save_plot <- function(plot, filename, width, height, dpi = 600) {
    pdf_path <- file.path(output_dir, paste0(filename, ".pdf"))
    png_path <- file.path(output_dir, paste0(filename, ".png"))
    pdf_device <- if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else grDevices::pdf
    ggplot2::ggsave(
      pdf_path, plot,
      width = width, height = height,
      units = "in", device = pdf_device, bg = "white"
    )
    ggplot2::ggsave(
      png_path, plot,
      width = width, height = height,
      units = "in", dpi = dpi, bg = "white"
    )
    message("Saved: ", pdf_path)
    message("Saved: ", png_path)
  }
}

find_shock_value_column <- function(x) {
  candidates <- c(
    "Shock_Value", "Shock_Occ", "Shock_Score", "Shock_Intensity",
    "Shock_Count_Std", "Shock_Std", "count_std", "count_scaled",
    "value", "count"
  )
  hit <- intersect(candidates, names(x))
  if (length(hit) == 0) return(NA_character_)
  hit[1]
}

standardize_shock_table <- function(x, region = NULL) {
  val_col <- find_shock_value_column(x)
  if (is.na(val_col)) {
    stop(
      "Could not detect a shock value column. Available columns: ",
      paste(names(x), collapse = ", ")
    )
  }
  
  y <- x %>%
    rename(Shock_Value = all_of(val_col))
  
  if (!("Risk_Type" %in% names(y))) {
    if ("Shock_Type" %in% names(y)) {
      y <- y %>% rename(Risk_Type = Shock_Type)
    } else if ("Shock.category" %in% names(y)) {
      y <- y %>% rename(Risk_Type = Shock.category)
    } else if ("Shock category" %in% names(y)) {
      y <- y %>% rename(Risk_Type = `Shock category`)
    } else {
      stop("Shock table must have Risk_Type, Shock_Type, or Shock.category.")
    }
  }
  
  y <- y %>%
    mutate(
      Risk_Type = dplyr::recode(
        as.character(Risk_Type), !!!map_risk,
        .default = as.character(Risk_Type)
      )
    ) %>%
    filter(!is.na(Risk_Type), Risk_Type %in% risk_levels)
  
  if (!is.null(region)) y <- y %>% mutate(Region = region)
  if (!("Region" %in% names(y))) stop("Shock table lacks Region and no region was supplied.")
  
  base <- y %>%
    mutate(
      Region = as.character(Region),
      Risk_Type = as.character(Risk_Type)
    ) %>%
    select(Region, Risk_Type, Year, Shock_Value) %>%
    group_by(Region, Risk_Type, Year) %>%
    summarise(Shock_Value = mean(Shock_Value, na.rm = TRUE), .groups = "drop")
  
  regions_present <- sort(unique(base$Region))
  coverage <- shock_coverage %>% mutate(Risk_Type = as.character(Risk_Type))
  
  # Complete true absences as zero only within the category-specific coverage
  # period. Years outside coverage are left absent so that downstream windows
  # become NA rather than structural zeros.
  grid <- tidyr::expand_grid(
    Region = regions_present,
    Risk_Type = risk_levels,
    Year = seq(analysis_first_year, analysis_last_year)
  ) %>%
    left_join(coverage, by = "Risk_Type") %>%
    filter(Year >= FirstYear, Year <= LastYear) %>%
    select(Region, Risk_Type, Year)
  
  grid %>%
    left_join(base, by = c("Region", "Risk_Type", "Year")) %>%
    mutate(
      Shock_Value = tidyr::replace_na(Shock_Value, 0),
      Region = factor(Region, levels = region_levels),
      Risk_Type = factor(Risk_Type, levels = risk_levels)
    ) %>%
    arrange(Region, Risk_Type, Year)
}

make_global_shock_table_for_section13 <- function(sh_nat_clean) {
  coverage <- shock_coverage %>% mutate(Risk_Type = as.character(Risk_Type))
  
  base <- sh_nat_clean %>%
    mutate(
      Risk_Type = dplyr::recode(
        Shock.category, !!!map_risk,
        .default = as.character(Shock.category)
      )
    ) %>%
    filter(!is.na(Risk_Type), Risk_Type %in% risk_levels) %>%
    mutate(Risk_Type = as.character(Risk_Type)) %>%
    group_by(Risk_Type, Year) %>%
    summarise(count = sum(count, na.rm = TRUE), .groups = "drop")
  
  grid <- tidyr::expand_grid(
    Risk_Type = risk_levels,
    Year = seq(analysis_first_year, analysis_last_year)
  ) %>%
    left_join(coverage, by = "Risk_Type") %>%
    filter(Year >= FirstYear, Year <= LastYear) %>%
    select(Risk_Type, Year)
  
  grid %>%
    left_join(base, by = c("Risk_Type", "Year")) %>%
    mutate(count = tidyr::replace_na(count, 0)) %>%
    group_by(Risk_Type) %>%
    mutate(
      sd_count = sd(count, na.rm = TRUE),
      Shock_Value = if_else(is.finite(sd_count) & sd_count > 0, count / sd_count, 0)
    ) %>%
    ungroup() %>%
    transmute(
      Region = factor("Global", levels = region_levels),
      Risk_Type = factor(Risk_Type, levels = risk_levels),
      Year,
      Shock_Value
    ) %>%
    arrange(Region, Risk_Type, Year)
}

shock_reg_year <- standardize_shock_table(sh_reg)

if (any(as.character(shock_reg_year$Region) == "Global")) {
  shock_global_year <- shock_reg_year %>% filter(Region == "Global")
} else {
  shock_global_year <- make_global_shock_table_for_section13(sh_nat)
}

shock_year_all <- bind_rows(
  shock_reg_year %>% filter(Region %in% income_levels),
  shock_global_year
) %>%
  mutate(
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

write.csv(
  shock_year_all,
  file.path(output_dir, "section13_shock_year_table_coverage_adjusted.csv"),
  row.names = FALSE
)

make_window_years <- function(year, horizon, direction) {
  if (direction == "future") {
    if (isTRUE(INCLUDE_RISK_YEAR_IN_WINDOWS)) {
      seq(year, year + horizon)
    } else {
      seq(year + 1, year + horizon)
    }
  } else if (direction == "past") {
    if (isTRUE(INCLUDE_RISK_YEAR_IN_WINDOWS)) {
      seq(year - horizon, year)
    } else {
      seq(year - horizon, year - 1)
    }
  } else {
    stop("direction must be either 'future' or 'past'.")
  }
}

get_window_summary <- function(shock_ts, region, risk_type, year, horizon, direction) {
  requested_years <- as.integer(make_window_years(year, horizon, direction))
  requested_years <- requested_years[!is.na(requested_years)]
  n_requested <- length(requested_years)
  
  if (n_requested == 0) {
    return(tibble(
      mean = NA_real_,
      n_available = 0L,
      n_requested = 0L,
      first_year_used = NA_integer_,
      last_year_used = NA_integer_
    ))
  }
  
  eval_years <- requested_years
  cov <- shock_coverage %>%
    filter(as.character(Risk_Type) == as.character(risk_type))
  
  if (nrow(cov) == 1) {
    if (isTRUE(SECTION13_ALLOW_PARTIAL_WINDOWS)) {
      # Keep the part of the requested window that lies inside known
      # category-specific shock-data coverage. Years outside coverage are not
      # counted as zero and are not part of the denominator.
      eval_years <- eval_years[
        eval_years >= cov$FirstYear[1] & eval_years <= cov$LastYear[1]
      ]
    } else {
      # Strict sensitivity mode: drop the whole window if any requested year
      # lies outside category-specific coverage.
      if (min(eval_years, na.rm = TRUE) < cov$FirstYear[1] ||
          max(eval_years, na.rm = TRUE) > cov$LastYear[1]) {
        return(tibble(
          mean = NA_real_,
          n_available = 0L,
          n_requested = n_requested,
          first_year_used = NA_integer_,
          last_year_used = NA_integer_
        ))
      }
    }
  }
  
  eval_years <- sort(unique(as.integer(eval_years)))
  
  if (length(eval_years) == 0) {
    return(tibble(
      mean = NA_real_,
      n_available = 0L,
      n_requested = n_requested,
      first_year_used = NA_integer_,
      last_year_used = NA_integer_
    ))
  }
  
  win <- shock_ts %>%
    filter(
      as.character(Region) == as.character(region),
      as.character(Risk_Type) == as.character(risk_type),
      Year %in% eval_years
    ) %>%
    group_by(Year) %>%
    summarise(Shock_Value = mean(Shock_Value, na.rm = TRUE), .groups = "drop")
  
  # Join to the requested, coverage-trimmed year grid so that missing rows in
  # the shock table are not silently ignored. Within coverage, true absences
  # should already have been zero-filled when shock_year_all was built.
  win_complete <- tibble(Year = eval_years) %>%
    left_join(win, by = "Year")
  
  vals <- win_complete$Shock_Value
  n_available <- sum(is.finite(vals))
  
  if (n_available < SECTION13_MIN_WINDOW_OBSERVED_YEARS) {
    return(tibble(
      mean = NA_real_,
      n_available = as.integer(n_available),
      n_requested = n_requested,
      first_year_used = NA_integer_,
      last_year_used = NA_integer_
    ))
  }
  
  if (!isTRUE(SECTION13_ALLOW_PARTIAL_WINDOWS) && n_available < n_requested) {
    return(tibble(
      mean = NA_real_,
      n_available = as.integer(n_available),
      n_requested = n_requested,
      first_year_used = NA_integer_,
      last_year_used = NA_integer_
    ))
  }
  
  used_years <- win_complete$Year[is.finite(vals)]
  
  tibble(
    mean = mean(vals, na.rm = TRUE),
    n_available = as.integer(n_available),
    n_requested = n_requested,
    first_year_used = as.integer(min(used_years, na.rm = TRUE)),
    last_year_used = as.integer(max(used_years, na.rm = TRUE))
  )
}

get_window_mean <- function(shock_ts, region, risk_type, year, horizon, direction) {
  get_window_summary(shock_ts, region, risk_type, year, horizon, direction)$mean[[1]]
}

get_window_n <- function(shock_ts, region, risk_type, year, horizon, direction) {
  get_window_summary(shock_ts, region, risk_type, year, horizon, direction)$n_available[[1]]
}

get_window_first_year <- function(shock_ts, region, risk_type, year, horizon, direction) {
  get_window_summary(shock_ts, region, risk_type, year, horizon, direction)$first_year_used[[1]]
}

get_window_last_year <- function(shock_ts, region, risk_type, year, horizon, direction) {
  get_window_summary(shock_ts, region, risk_type, year, horizon, direction)$last_year_used[[1]]
}

fit_lm_slope_safe <- function(dat, response_col, min_n = 5) {
  d <- dat %>%
    filter(
      is.finite(Risk_Score),
      is.finite(.data[[response_col]])
    )
  
  if (
    nrow(d) < min_n ||
    length(unique(d$Risk_Score)) < 2 ||
    length(unique(d[[response_col]])) < 2
  ) {
    return(tibble(
      estimate = NA_real_,
      std.error = NA_real_,
      p.value = NA_real_,
      n = nrow(d)
    ))
  }
  
  fit <- lm(reformulate("Risk_Score", response = response_col), data = d)
  
  broom::tidy(fit) %>%
    filter(term == "Risk_Score") %>%
    transmute(
      estimate = estimate,
      std.error = std.error,
      p.value = p.value,
      n = nrow(d)
    )
}


finite_min_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  min(x)
}

finite_mean_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  mean(x)
}

finite_max_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0) return(NA_real_)
  max(x)
}

compute_year_region_horizon <- function(region, year, horizon, shock_ts, risk_ts,
                                        risk_set = risk_levels, min_n = 5) {
  dat <- risk_ts %>%
    filter(Year == year, as.character(Risk_Type) %in% risk_set) %>%
    mutate(
      Risk_Type = as.character(Risk_Type),
      Risk_Score = suppressWarnings(as.numeric(Risk_Score)),
      Region = region,
      future_shocks = map_dbl(
        Risk_Type,
        ~ get_window_mean(shock_ts, region, .x, year, horizon, "future")
      ),
      past_shocks = map_dbl(
        Risk_Type,
        ~ get_window_mean(shock_ts, region, .x, year, horizon, "past")
      ),
      future_window_years = map_int(
        Risk_Type,
        ~ get_window_n(shock_ts, region, .x, year, horizon, "future")
      ),
      past_window_years = map_int(
        Risk_Type,
        ~ get_window_n(shock_ts, region, .x, year, horizon, "past")
      )
    )
  
  fut <- fit_lm_slope_safe(dat, "future_shocks", min_n = min_n)
  pst <- fit_lm_slope_safe(dat, "past_shocks", min_n = min_n)
  
  tibble(
    Region = region,
    Year = year,
    horizon = horizon,
    n_future = fut$n,
    n_past = pst$n,
    future_window_years_min = finite_min_or_na(dat$future_window_years[is.finite(dat$future_shocks)]),
    future_window_years_mean = finite_mean_or_na(dat$future_window_years[is.finite(dat$future_shocks)]),
    future_window_years_max = finite_max_or_na(dat$future_window_years[is.finite(dat$future_shocks)]),
    past_window_years_min = finite_min_or_na(dat$past_window_years[is.finite(dat$past_shocks)]),
    past_window_years_mean = finite_mean_or_na(dat$past_window_years[is.finite(dat$past_shocks)]),
    past_window_years_max = finite_max_or_na(dat$past_window_years[is.finite(dat$past_shocks)]),
    predictive_capacity = fut$estimate,
    predictive_capacity_se = fut$std.error,
    predictive_capacity_p = fut$p.value,
    past_at_horizon = pst$estimate,
    past_at_horizon_se = pst$std.error,
    past_at_horizon_p = pst$p.value
  )
}

select_best_horizon_by_year <- function(x) {
  x %>%
    filter(is.finite(predictive_capacity)) %>%
    group_by(Region, Year) %>%
    arrange(desc(predictive_capacity), horizon, .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(
      best_horizon = horizon,
      past_at_best_horizon = past_at_horizon,
      anticipatory_skill = predictive_capacity - past_at_best_horizon
    )
}

# All-risk edition-level analysis.
gr_year_values <- sort(unique(risks_long$Year))

grr_year_by_horizon <- expand_grid(
  Region = region_levels,
  Year = gr_year_values,
  horizon = 1:5
) %>%
  pmap_dfr(
    ~ compute_year_region_horizon(
      region = ..1,
      year = ..2,
      horizon = ..3,
      shock_ts = shock_year_all,
      risk_ts = risks_long,
      risk_set = risk_levels,
      min_n = 5
    )
  ) %>%
  mutate(Region = factor(as.character(Region), levels = region_levels))

grr_year_performance <- select_best_horizon_by_year(grr_year_by_horizon)

write.csv(
  grr_year_by_horizon,
  file.path(output_dir, "grr_year_performance_by_horizon.csv"),
  row.names = FALSE
)
write.csv(
  grr_year_performance,
  file.path(output_dir, "grr_year_performance_best_horizon.csv"),
  row.names = FALSE
)

best_grr_years_by_region <- bind_rows(
  grr_year_performance %>%
    group_by(Region) %>%
    arrange(desc(predictive_capacity), .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(metric = "Predictive capacity", value = predictive_capacity),
  grr_year_performance %>%
    group_by(Region) %>%
    arrange(desc(anticipatory_skill), .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(metric = "Anticipatory skill", value = anticipatory_skill)
) %>%
  select(
    Region, metric, Year, best_horizon, value,
    predictive_capacity, past_at_best_horizon, anticipatory_skill,
    n_future, n_past,
    future_window_years_min, future_window_years_mean, future_window_years_max,
    past_window_years_min, past_window_years_mean, past_window_years_max
  )

write.csv(
  best_grr_years_by_region,
  file.path(output_dir, "best_grr_years_by_region.csv"),
  row.names = FALSE
)

trend_one <- function(dat, outcome) {
  dat <- dat %>% filter(is.finite(.data[[outcome]]), is.finite(Year))
  if (nrow(dat) < 4) {
    return(tibble(slope = NA_real_, p_value = NA_real_, n = nrow(dat)))
  }
  fit <- lm(reformulate("Year", response = outcome), data = dat)
  sm <- summary(fit)$coefficients
  tibble(
    slope = unname(sm["Year", "Estimate"]),
    p_value = unname(sm["Year", "Pr(>|t|)"]),
    n = nrow(dat)
  )
}

grr_year_trend_tests <- grr_year_performance %>%
  group_by(Region) %>%
  group_modify(~ bind_rows(
    trend_one(.x, "predictive_capacity") %>% mutate(metric = "Predictive capacity"),
    trend_one(.x, "anticipatory_skill") %>% mutate(metric = "Anticipatory skill")
  )) %>%
  ungroup() %>%
  select(Region, metric, slope, p_value, n)

write.csv(
  grr_year_trend_tests,
  file.path(output_dir, "grr_year_trend_tests.csv"),
  row.names = FALSE
)

# Figure: all-risk GRR-year time series.
gr_year_plot_dat <- grr_year_performance %>%
  select(Region, Year, best_horizon, predictive_capacity, anticipatory_skill) %>%
  pivot_longer(
    cols = c(predictive_capacity, anticipatory_skill),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric = dplyr::recode(
      metric,
      predictive_capacity = "Predictive capacity",
      anticipatory_skill = "Anticipatory skill"
    ),
    metric = factor(metric, levels = c("Predictive capacity", "Anticipatory skill"))
  )

best_label_dat <- gr_year_plot_dat %>%
  group_by(Region, metric) %>%
  arrange(desc(value), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  mutate(label = paste0(Year, " (h = ", best_horizon, ")"))

figure_grr_year_timeseries <- ggplot(
  gr_year_plot_dat,
  aes(x = Year, y = value, colour = metric, shape = metric)
) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.35) +
  geom_line(linewidth = 0.55, alpha = 0.85, na.rm = TRUE) +
  geom_point(size = 2.0, na.rm = TRUE) +
  geom_text(
    data = best_label_dat,
    aes(label = label),
    hjust = -0.05,
    vjust = -0.15,
    size = 2.7,
    show.legend = FALSE
  ) +
  facet_wrap(~ Region, ncol = 1) +
  scale_x_continuous(
    breaks = gr_year_values,
    expand = expansion(mult = c(0.02, 0.12))
  ) +
  scale_colour_manual(
    values = c(
      "Predictive capacity" = "#0072B2",
      "Anticipatory skill" = "#D55E00"
    )
  ) +
  scale_shape_manual(
    values = c(
      "Predictive capacity" = 16,
      "Anticipatory skill" = 17
    )
  ) +
  labs(
    x = "GRR year",
    y = "Edition-level regression coefficient / skill",
    colour = NULL,
    shape = NULL
  ) +
  theme_bw(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    strip.background = element_rect(fill = "grey92", colour = "grey70"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

save_plot(
  figure_grr_year_timeseries,
  "Figure_S_GRR_year_performance_timeseries_all_risks",
  width = 8.5,
  height = 9.2
)

# Targeted edition-level analysis, for tables only. No extra figures are saved.
if (exists("target_risks")) {
  target_risks_section13 <- as.character(target_risks)
} else if (exists("TARGET_RISKS_POSITIVE_GLOBAL")) {
  target_risks_section13 <- TARGET_RISKS_POSITIVE_GLOBAL
} else if (exists("comp_summary_all")) {
  target_risks_section13 <- comp_summary_all %>%
    filter(term == "Risk_Score", as.character(Region) == "Global", max_future > 0) %>%
    pull(Risk_Type) %>%
    as.character()
} else {
  target_risks_section13 <- c("Climate", "Diseases", "GeoConflict", "Terror")
}

target_risks <- target_risks_section13

grr_year_by_horizon_targeted <- expand_grid(
  Region = region_levels,
  Year = gr_year_values,
  horizon = 1:5
) %>%
  pmap_dfr(
    ~ compute_year_region_horizon(
      region = ..1,
      year = ..2,
      horizon = ..3,
      shock_ts = shock_year_all,
      risk_ts = risks_long,
      risk_set = target_risks_section13,
      min_n = min(4, length(target_risks_section13))
    )
  ) %>%
  mutate(Region = factor(as.character(Region), levels = region_levels))

grr_year_performance_targeted <- select_best_horizon_by_year(grr_year_by_horizon_targeted) %>%
  mutate(risk_set = paste(risk_label(target_risks_section13), collapse = ", "))

write.csv(
  grr_year_by_horizon_targeted,
  file.path(output_dir, "grr_year_performance_by_horizon_targeted_positive_global_risks.csv"),
  row.names = FALSE
)
write.csv(
  grr_year_performance_targeted,
  file.path(output_dir, "grr_year_performance_best_horizon_targeted_positive_global_risks.csv"),
  row.names = FALSE
)

best_grr_years_by_region_targeted <- bind_rows(
  grr_year_performance_targeted %>%
    group_by(Region) %>%
    arrange(desc(predictive_capacity), .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(metric = "Predictive capacity", value = predictive_capacity),
  grr_year_performance_targeted %>%
    group_by(Region) %>%
    arrange(desc(anticipatory_skill), .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(metric = "Anticipatory skill", value = anticipatory_skill)
) %>%
  select(
    Region, metric, Year, best_horizon, value,
    predictive_capacity, past_at_best_horizon, anticipatory_skill,
    n_future, n_past,
    future_window_years_min, future_window_years_mean, future_window_years_max,
    past_window_years_min, past_window_years_mean, past_window_years_max,
    risk_set
  )

write.csv(
  best_grr_years_by_region_targeted,
  file.path(output_dir, "best_grr_years_by_region_targeted_positive_global_risks.csv"),
  row.names = FALSE
)

grr_year_trend_tests_targeted <- grr_year_performance_targeted %>%
  group_by(Region) %>%
  group_modify(~ bind_rows(
    trend_one(.x, "predictive_capacity") %>% mutate(metric = "Predictive capacity"),
    trend_one(.x, "anticipatory_skill") %>% mutate(metric = "Anticipatory skill")
  )) %>%
  ungroup() %>%
  select(Region, metric, slope, p_value, n)

write.csv(
  grr_year_trend_tests_targeted,
  file.path(output_dir, "grr_year_trend_tests_targeted_positive_global_risks.csv"),
  row.names = FALSE
)

# ----------------------------------------------------------------------
# 13B. Category-specific GRR performance through time
# ----------------------------------------------------------------------
# This section creates two global all-risk figures:
# 1. A pointwise annual-component diagnostic using the main terms.
# 2. Rolling category-specific predictive capacity and anticipatory skill.
# ----------------------------------------------------------------------

required_objects_13B <- c(
  "shock_year_all", "get_window_mean", "risks_long", "comp_summary_all",
  "output_dir", "risk_levels", "region_levels"
)

missing_objects_13B <- required_objects_13B[
  !vapply(required_objects_13B, exists, logical(1))
]

if (length(missing_objects_13B) > 0) {
  stop(
    "Section 13B must be run after Section 13. Missing object(s): ",
    paste(missing_objects_13B, collapse = ", ")
  )
}

if (!exists("risk_pal")) {
  risk_pal <- c(
    "Geophysical" = "#999999",
    "Climate" = "#E69F00",
    "Diseases" = "#56B4E9",
    "Food" = "#009E73",
    "Economic" = "#D55E00",
    "GeoConflict" = "#0072B2",
    "Terror" = "#CC79A7",
    "Tech" = "#000000"
  )
}

z_within <- function(x) {
  sx <- sd(x, na.rm = TRUE)
  mx <- mean(x, na.rm = TRUE)
  
  if (!is.finite(sx) || sx == 0) {
    return(rep(NA_real_, length(x)))
  }
  
  (x - mx) / sx
}

roll_mean_safe <- function(x, k = 3, min_non_missing = 1, require_center = TRUE) {
  # Centered rolling mean for diagnostic display.
  # With partial-window diagnostics, end-of-series annual components can remain
  # available even when the requested future horizon is only partly observed. The
  # line therefore follows the available annual component. Requiring the central
  # value prevents smoothing through genuinely missing annual components.
  n <- length(x)
  out <- rep(NA_real_, n)
  half <- floor(k / 2)
  
  for (i in seq_along(x)) {
    if (isTRUE(require_center) && !is.finite(x[i])) next
    
    idx <- seq(i - half, i + half)
    idx <- idx[idx >= 1 & idx <= n]
    ok <- is.finite(x[idx])
    
    if (sum(ok) >= min_non_missing) {
      out[i] <- mean(x[idx][ok], na.rm = TRUE)
    }
  }
  
  out
}

# Risk selection check for targeted tables and captions.
global_positive_capacity_selection <- comp_summary_all %>%
  filter(term == "Risk_Score", as.character(Region) == "Global") %>%
  mutate(
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels),
    selected_positive_global_predictive_capacity = max_future > 0
  ) %>%
  arrange(Risk_Type) %>%
  select(
    Risk_Type,
    max_future,
    diff_future_corrpast,
    lag_max,
    selected_positive_global_predictive_capacity
  )

target_risks <- global_positive_capacity_selection %>%
  filter(selected_positive_global_predictive_capacity) %>%
  pull(Risk_Type) %>%
  as.character()

write.csv(
  global_positive_capacity_selection,
  file.path(output_dir, "global_positive_predictive_capacity_risk_selection.csv"),
  row.names = FALSE
)

message(
  "Risks with positive global predictive capacity: ",
  paste(risk_label(target_risks), collapse = ", ")
)

# 13B.1. Annual-component diagnostic at the full-period best horizon.
category_best_horizons <- comp_summary_all %>%
  filter(term == "Risk_Score") %>%
  transmute(
    Region = as.character(Region),
    Risk_Type = as.character(Risk_Type),
    best_horizon = as.integer(lag_max)
  ) %>%
  mutate(best_horizon = if_else(is.na(best_horizon), 1L, best_horizon))

category_year_dat <- expand_grid(
  Region = region_levels,
  Risk_Type = risk_levels,
  Year = sort(unique(risks_long$Year))
) %>%
  left_join(
    risks_long %>%
      mutate(
        Risk_Type = as.character(Risk_Type),
        Risk_Score = suppressWarnings(as.numeric(Risk_Score))
      ) %>%
      select(Year, Risk_Type, Risk_Score),
    by = c("Year", "Risk_Type")
  ) %>%
  left_join(category_best_horizons, by = c("Region", "Risk_Type")) %>%
  mutate(
    best_horizon = if_else(is.na(best_horizon), 1L, best_horizon),
    future_shocks = pmap_dbl(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_mean(shock_year_all, ..1, ..2, ..3, ..4, "future")
    ),
    past_shocks = pmap_dbl(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_mean(shock_year_all, ..1, ..2, ..3, ..4, "past")
    ),
    future_window_years = pmap_int(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_n(shock_year_all, ..1, ..2, ..3, ..4, "future")
    ),
    past_window_years = pmap_int(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_n(shock_year_all, ..1, ..2, ..3, ..4, "past")
    ),
    future_window_first_year = pmap_int(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_first_year(shock_year_all, ..1, ..2, ..3, ..4, "future")
    ),
    future_window_last_year = pmap_int(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_last_year(shock_year_all, ..1, ..2, ..3, ..4, "future")
    ),
    past_window_first_year = pmap_int(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_first_year(shock_year_all, ..1, ..2, ..3, ..4, "past")
    ),
    past_window_last_year = pmap_int(
      list(Region, Risk_Type, Year, best_horizon),
      ~ get_window_last_year(shock_year_all, ..1, ..2, ..3, ..4, "past")
    )
  ) %>%
  group_by(Region, Risk_Type) %>%
  arrange(Year, .by_group = TRUE) %>%
  mutate(
    z_risk = z_within(Risk_Score),
    z_future = z_within(future_shocks),
    z_past = z_within(past_shocks),
    predictive_capacity_component = z_risk * z_future,
    past_component = z_risk * z_past,
    anticipatory_skill_component = predictive_capacity_component - past_component,
    predictive_capacity_component_roll3 = roll_mean_safe(
      predictive_capacity_component,
      k = 3,
      min_non_missing = SECTION13_ROLLING_MEAN_MIN_NON_MISSING,
      require_center = SECTION13_ROLLING_MEAN_REQUIRE_CENTER
    ),
    anticipatory_skill_component_roll3 = roll_mean_safe(
      anticipatory_skill_component,
      k = 3,
      min_non_missing = SECTION13_ROLLING_MEAN_MIN_NON_MISSING,
      require_center = SECTION13_ROLLING_MEAN_REQUIRE_CENTER
    )
  ) %>%
  ungroup() %>%
  mutate(
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

write.csv(
  category_year_dat,
  file.path(output_dir, "grr_year_category_pointwise_alignment_all_regions_all_risks.csv"),
  row.names = FALSE
)

# 13B.2. Rolling regression-based predictive capacity by category.
category_year_horizon_dat <- expand_grid(
  Region = region_levels,
  Risk_Type = risk_levels,
  Year = sort(unique(risks_long$Year)),
  horizon = 1:5
) %>%
  left_join(
    risks_long %>%
      mutate(
        Risk_Type = as.character(Risk_Type),
        Risk_Score = suppressWarnings(as.numeric(Risk_Score))
      ) %>%
      select(Year, Risk_Type, Risk_Score),
    by = c("Year", "Risk_Type")
  ) %>%
  mutate(
    future_shocks = pmap_dbl(
      list(Region, Risk_Type, Year, horizon),
      ~ get_window_mean(shock_year_all, ..1, ..2, ..3, ..4, "future")
    ),
    past_shocks = pmap_dbl(
      list(Region, Risk_Type, Year, horizon),
      ~ get_window_mean(shock_year_all, ..1, ..2, ..3, ..4, "past")
    ),
    future_window_years = pmap_int(
      list(Region, Risk_Type, Year, horizon),
      ~ get_window_n(shock_year_all, ..1, ..2, ..3, ..4, "future")
    ),
    past_window_years = pmap_int(
      list(Region, Risk_Type, Year, horizon),
      ~ get_window_n(shock_year_all, ..1, ..2, ..3, ..4, "past")
    ),
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

write.csv(
  category_year_horizon_dat,
  file.path(output_dir, "grr_year_category_by_horizon_all_regions_all_risks.csv"),
  row.names = FALSE
)

rolling_capacity_one <- function(dat, center_year, half_window = 3, min_n = 5) {
  yrs <- seq(center_year - half_window, center_year + half_window)
  d <- dat %>% filter(Year %in% yrs)
  
  horizon_results <- map_dfr(sort(unique(d$horizon)), function(h) {
    dh <- d %>% filter(horizon == h)
    fut <- fit_lm_slope_safe(dh, "future_shocks", min_n = min_n)
    pst <- fit_lm_slope_safe(dh, "past_shocks", min_n = min_n)
    
    tibble(
      horizon = as.integer(h),
      future_estimate = fut$estimate,
      future_se = fut$std.error,
      future_p = fut$p.value,
      n_future = fut$n,
      past_estimate = pst$estimate,
      past_se = pst$std.error,
      past_p = pst$p.value,
      n_past = pst$n
    )
  })
  
  if (!any(is.finite(horizon_results$future_estimate))) {
    return(tibble(
      center_year = center_year,
      start_year = min(yrs),
      end_year = max(yrs),
      best_horizon = NA_integer_,
      rolling_predictive_capacity = NA_real_,
      rolling_predictive_capacity_se = NA_real_,
      rolling_predictive_capacity_p = NA_real_,
      rolling_past_at_best_horizon = NA_real_,
      rolling_past_at_best_horizon_se = NA_real_,
      rolling_past_at_best_horizon_p = NA_real_,
      rolling_anticipatory_skill = NA_real_,
      n_future = NA_integer_,
      n_past = NA_integer_
    ))
  }
  
  best <- horizon_results %>%
    filter(is.finite(future_estimate)) %>%
    arrange(desc(future_estimate), horizon) %>%
    slice(1)
  
  tibble(
    center_year = center_year,
    start_year = min(yrs),
    end_year = max(yrs),
    best_horizon = best$horizon,
    rolling_predictive_capacity = best$future_estimate,
    rolling_predictive_capacity_se = best$future_se,
    rolling_predictive_capacity_p = best$future_p,
    rolling_past_at_best_horizon = best$past_estimate,
    rolling_past_at_best_horizon_se = best$past_se,
    rolling_past_at_best_horizon_p = best$past_p,
    rolling_anticipatory_skill = best$future_estimate - best$past_estimate,
    n_future = best$n_future,
    n_past = best$n_past
  )
}

rolling_year_category_performance <- category_year_horizon_dat %>%
  group_by(Region, Risk_Type) %>%
  group_modify(function(d, key) {
    map_dfr(
      sort(unique(d$Year)),
      ~ rolling_capacity_one(d, center_year = .x, half_window = 3, min_n = 5)
    )
  }) %>%
  ungroup() %>%
  mutate(
    Region = factor(as.character(Region), levels = region_levels),
    Risk_Type = factor(as.character(Risk_Type), levels = risk_levels)
  )

write.csv(
  rolling_year_category_performance,
  file.path(output_dir, "grr_year_category_rolling_performance_all_regions_all_risks.csv"),
  row.names = FALSE
)

# 13B.3. Plot helpers.
make_category_pointwise_plot <- function(plot_risks, suffix, width = 12.5, height = 9.2) {
  metric_levels <- c(
    "Predictive capacity (annual component)",
    "Anticipatory skill (annual component)"
  )
  
  panel_levels <- unlist(lapply(plot_risks, function(r) {
    paste0(risk_label(r), "\n", metric_levels)
  }))
  
  plot_dat <- category_year_dat %>%
    filter(Region == "Global", as.character(Risk_Type) %in% plot_risks) %>%
    select(
      Year,
      Risk_Type,
      best_horizon,
      predictive_capacity_component,
      anticipatory_skill_component,
      predictive_capacity_component_roll3,
      anticipatory_skill_component_roll3
    ) %>%
    pivot_longer(
      cols = c(predictive_capacity_component, anticipatory_skill_component),
      names_to = "metric",
      values_to = "value"
    ) %>%
    mutate(
      metric = dplyr::recode(
        metric,
        predictive_capacity_component = "Predictive capacity (annual component)",
        anticipatory_skill_component = "Anticipatory skill (annual component)"
      ),
      smooth_value = if_else(
        metric == "Predictive capacity (annual component)",
        predictive_capacity_component_roll3,
        anticipatory_skill_component_roll3
      ),
      Risk_Type = factor(as.character(Risk_Type), levels = plot_risks),
      panel = factor(
        paste0(risk_label(Risk_Type), "\n", metric),
        levels = panel_levels
      )
    )
  
  p <- ggplot(
    plot_dat,
    aes(x = Year, y = value, fill = Risk_Type, colour = Risk_Type)
  ) +
    geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.30) +
    geom_col(width = 0.75, alpha = 0.45) +
    geom_line(aes(y = smooth_value), linewidth = 0.70, na.rm = TRUE) +
    facet_wrap(~ panel, ncol = 4, scales = "free_y") +
    scale_fill_manual(
      values = risk_pal,
      breaks = plot_risks,
      labels = risk_label(plot_risks),
      drop = FALSE,
      guide = "none"
    ) +
    scale_colour_manual(
      values = risk_pal,
      breaks = plot_risks,
      labels = risk_label(plot_risks),
      drop = FALSE,
      guide = "none"
    ) +
    scale_x_continuous(breaks = sort(unique(risks_long$Year))) +
    labs(
      x = "GRR year",
      y = "Annual standardized component"
    ) +
    theme_bw(base_size = 8.5) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "grey92", colour = "grey70"),
      strip.text = element_text(size = 7.6, face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 6.5),
      axis.text.y = element_text(size = 7),
      panel.spacing = unit(0.55, "lines")
    )
  
  save_plot(
    p,
    paste0("Figure_S_GRR_year_category_pointwise_alignment_global_", suffix),
    width = width,
    height = height
  )
  
  p
}

make_category_rolling_capacity_plot <- function(plot_risks, suffix, width = 12.5, height = 7.0) {
  plot_dat <- rolling_year_category_performance %>%
    filter(Region == "Global", as.character(Risk_Type) %in% plot_risks) %>%
    select(
      Risk_Type,
      center_year,
      best_horizon,
      rolling_predictive_capacity,
      rolling_anticipatory_skill
    ) %>%
    pivot_longer(
      cols = c(rolling_predictive_capacity, rolling_anticipatory_skill),
      names_to = "metric",
      values_to = "value"
    ) %>%
    mutate(
      metric = dplyr::recode(
        metric,
        rolling_predictive_capacity = "Predictive capacity",
        rolling_anticipatory_skill = "Anticipatory skill"
      ),
      metric = factor(metric, levels = c("Predictive capacity", "Anticipatory skill")),
      Risk_Type = factor(as.character(Risk_Type), levels = plot_risks)
    )
  
  p <- ggplot(
    plot_dat,
    aes(x = center_year, y = value, colour = metric, shape = metric)
  ) +
    geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.30) +
    geom_line(linewidth = 0.65, alpha = 0.9, na.rm = TRUE) +
    geom_point(size = 1.8, na.rm = TRUE) +
    facet_wrap(
      ~ Risk_Type,
      ncol = 4,
      scales = "free_y",
      labeller = labeller(Risk_Type = risk_label)
    ) +
    scale_x_continuous(breaks = sort(unique(risks_long$Year))) +
    scale_colour_manual(
      values = c(
        "Predictive capacity" = "#0072B2",
        "Anticipatory skill" = "#D55E00"
      )
    ) +
    scale_shape_manual(
      values = c(
        "Predictive capacity" = 16,
        "Anticipatory skill" = 17
      )
    ) +
    labs(
      x = "Central GRR year in 7-year rolling window",
      y = "Rolling regression coefficient / skill",
      colour = NULL,
      shape = NULL
    ) +
    theme_bw(base_size = 9) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      strip.background = element_rect(fill = "grey92", colour = "grey70"),
      strip.text = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      panel.spacing = unit(0.65, "lines")
    )
  
  save_plot(
    p,
    paste0("Figure_S_GRR_year_category_rolling_performance_global_", suffix),
    width = width,
    height = height
  )
  
  p
}

# 13B.4. Save the all-risk figures planned for the revision.
figure_grr_year_category_pointwise_all <- make_category_pointwise_plot(
  plot_risks = risk_levels,
  suffix = "all_risks",
  width = 12.5,
  height = 9.2
)

figure_grr_year_category_rolling_all <- make_category_rolling_capacity_plot(
  plot_risks = risk_levels,
  suffix = "all_risks",
  width = 12.5,
  height = 7.0
)

message("\nUpdated Section 13 and 13B outputs saved in: ", output_dir)
message("  - Figure_S_GRR_year_performance_timeseries_all_risks.pdf/png")
message("  - Figure_S_GRR_year_category_pointwise_alignment_global_all_risks.pdf/png")
message("  - Figure_S_GRR_year_category_rolling_performance_global_all_risks.pdf/png")
message("  - grr_year_performance_by_horizon.csv")
message("  - grr_year_performance_best_horizon.csv")
message("  - grr_year_category_pointwise_alignment_all_regions_all_risks.csv")
message("  - grr_year_category_by_horizon_all_regions_all_risks.csv")
message("  - grr_year_category_rolling_performance_all_regions_all_risks.csv")

# ----------------------------------------------------------------------
# 14. Console summary of the key added results
# ----------------------------------------------------------------------

message("\nTarget risks used for the main income-group comparison: ", target_risk_label)
message("\nGlobal target-risk selection check:")
print(global_target_risk_check)

message("\nTargeted income-group Friedman tests:")
print(income_test_summary_targeted)

if (exists("income_test_summary_allrisks")) {
  message("\nAll-risk income-group Friedman tests, saved only as a sensitivity table:")
  print(income_test_summary_allrisks)
}

message("\nBest GRR years by region, all risks:")
print(best_grr_years_by_region)

message("\nGRR-year trend tests, all risks:")
print(grr_year_trend_tests)

expected_figure_basenames <- c(
  "Figure_1_global_revised",
  "Figure_2_top_left_revised",
  "Figure_2_top_right_revised",
  "Figure_S6_regional_simulation_results_revised",
  "Figure_S_GRR_year_category_pointwise_alignment_global_all_risks",
  "Figure_S_GRR_year_category_rolling_performance_global_all_risks",
  "Figure_S_GRR_year_performance_timeseries_all_risks",
  "Figure_S_income_group_targeted_friedman_ranks",
  "Figure_S_income_group_targeted_metric_profiles",
  "Figure_S_metric_parametric_CI_all_risks",
  "Figure_S_metric_randomization_intervals_all_risks"
)

message("\nExpected figure files saved as PDF and PNG:")
print(expected_figure_basenames)
message("\nAll outputs saved in: ", output_dir)

# ======================================================================
# End of script
# ======================================================================

